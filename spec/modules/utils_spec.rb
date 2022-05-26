# frozen_string_literal: true

NOT_EVENT_REPLIES = ['', ' ', '  ', '1', '123', '!!', 'hello', 'mug',
                     'in!', 'in in', 'intense', 'interest', 'individual', 'in case you thought', 'in 3 instances', 'just in case',
                     'out!', 'out out', 'outdo', 'outlawed', 'outrun', 'outspoken', 'out of hand', '3 out of 4'].freeze

EVENT_REPLIES = ['in', 'in +1', 'in +123', 'in +99999999', 'IN', 'IN ', 'IN +6', 'IN     +322', 'IN +0',
                 'out', 'out +2', 'out +456', 'out +99999999', 'OUT', 'OUT ', 'OUT   +7', 'OUT +449', 'OUT +0'].freeze

NOT_KEYWORD_REPLIES = ['', ' ', '  ', 'create', 'make', 'text', 'rocks', 'event', 'sub', 'add event'].freeze

RSpec.describe Utils do
  include Utils

  let(:sms_client) { class_double(SmsClient).as_stubbed_const }

  describe '.event_reply?' do
    NOT_EVENT_REPLIES.each do |reply|
      it "properly identifies \"#{reply}\" as `false`" do
        expect(Utils.event_reply?(reply)).to be(false)
      end
    end

    EVENT_REPLIES.each do |reply|
      it "properly identifies \"#{reply}\" as `true`" do
        expect(Utils.event_reply?(reply)).to be(true)
      end
    end
  end

  describe '.keyword_reply?' do
    NOT_KEYWORD_REPLIES.each do |reply|
      it "properly identifies \"#{reply}\" as `false`" do
        expect(Utils.keyword_reply?(reply)).to be(false)
      end
    end

    [*KEYWORD_REPLIES, *CARRIER_RESERVED_KEYWORDS].each do |reply|
      it "properly identifies \"#{reply}\" as `true`" do
        expect(Utils.keyword_reply?(reply)).to be(true)
      end
    end
  end

  describe '.strip_nondigits' do
    [
      ['abc 123', '123'],
      ['STATUS 999888', '999888'],
      ['IN 4', '4'],
      ['IN +2', '2'],
      ['4533', '4533'],
      ['no digits', ''],
      ['$$#$%**', ''],
      ['$%)(*(22)_+<<<', '22']
    ].each do |test|
      it 'properly returns only digits' do
        expect(Utils.strip_nondigits(test[0])).to eql(test[1])
      end
    end
  end

  describe '.collect_counts_for_timeframe' do
    it 'returns the number of IN/OUT responses for a given timeframe' do
      expect(sms_client).to receive(:sms_responses_for_timeframe)
        .with(start_date: '2022-05-24 19:01:00', end_date: '2022-05-25 19:01:00')
        .and_return({ responses: [
          { response: 'IN' },
          { response: 'IN +2' },
          { response: 'IN + 1' },
          { response: 'IN +0' },
          { response: 'OUT' },
          { response: 'not a event reply' }
        ] }.as_json)

      expect(
        Utils.collect_counts_for_timeframe(start_date: '2022-05-24 19:01:00',
                                           end_date: '2022-05-25 19:01:00')
      ).to eq({ in: 7, out: 1 })
    end
  end

  describe '.lists_for_display' do
    it 'returns a concatenated string of list names' do
      expect(sms_client).to receive(:lists)
        .and_return({ lists: [
          { name: 'List A' },
          { name: 'List B' },
          { name: 'List C' }
        ] }.as_json)

      expect(Utils.lists_for_display).to eq('List A, List B, List C')
    end
  end

  describe '.find_list_id_matching_name' do
    describe 'when a matching list name is found' do
      it 'returns the list ID' do
        expect(sms_client).to receive(:lists)
          .and_return({ lists: [
            { id: 1, name: 'List A' },
            { id: 2, name: 'List B' },
            { id: 3, name: 'List C' }
          ] }.as_json)

        expect(Utils.find_list_id_matching_name('LIST B')).to eq(2)
      end
    end

    describe 'when a matching list name cannot be found' do
      it 'returns nil' do
        expect(sms_client).to receive(:lists)
          .and_return({ lists: [
            { id: 1, name: 'List A' },
            { id: 2, name: 'List B' },
            { id: 3, name: 'List C' }
          ] }.as_json)

        expect(Utils.find_list_id_matching_name('NON MATCHING LIST NAME')).to be_nil
      end
    end
  end

  describe '.event_decision_audience' do
    it 'filters "OUT" responses, keeping only "IN" responses & those who did not respond' do
      message_id = 12345
      message_sent_at = '2022-05-26 06:35:00'

      expect(sms_client).to receive(:recipients_for_message)
        .with(message_id: message_id)
        .and_return({ recipients: [
          { msisdn: 1111111111 },
          { msisdn: 2222222222  },
          { msisdn: 3333333333  },
          { msisdn: 4444444444  },
          { msisdn: 5555555555  }
        ] }.as_json)

      expect(sms_client).to receive(:read_sms).with(message_id: message_id).and_return({ send_at: message_sent_at }.as_json)

      expect(sms_client).to receive(:sms_responses_for_timeframe)
        .with(start_date: message_sent_at, end_date: nil)
        .and_return({
          responses: [
            { msisdn: 1111111111, response: 'IN' },
            { msisdn: 2222222222, response: 'OUT' },
            { msisdn: 4444444444, response: 'OUT' },
            { msisdn: 5555555555, response: 'IN +2' }
          ]
        }.as_json)

      expect(Utils.event_decision_audience(message_id: message_id)).to eql('1111111111,3333333333,5555555555')
    end
  end

  describe '.nudge_audience' do
    it 'returns a list of numbers who have not responded to a message' do
      message_id = 12345
      message_sent_at = '2022-05-26 06:35:00'

      expect(sms_client).to receive(:recipients_for_message)
        .with(message_id: message_id)
        .and_return({ recipients: [
          { msisdn: 1111111111 },
          { msisdn: 2222222222  },
          { msisdn: 3333333333  },
          { msisdn: 4444444444  },
          { msisdn: 5555555555  }
        ] }.as_json)

      expect(sms_client).to receive(:read_sms).with(message_id: message_id).and_return({ send_at: message_sent_at }.as_json)

      expect(sms_client).to receive(:sms_responses_for_timeframe).with(start_date: message_sent_at, end_date: nil).and_return({
        responses: [
          { msisdn: 3333333333, response: 'OUT' },
          { msisdn: 4444444444, response: 'OUT' },
          { msisdn: 5555555555, response: 'IN +2' }
        ]
      }.as_json)

      expect(Utils.nudge_audience(message_id: message_id)).to eql('1111111111,2222222222')
    end
  end
end
