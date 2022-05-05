# frozen_string_literal: true

NOT_EVENT_REPLIES = ['', ' ', '  ', '1', '123', '!!', 'hello', 'mug',
                     'in!', 'in in', 'intense', 'interest', 'individual', 'in case you thought', 'in 3 instances', 'just in case',
                     'out!', 'out out', 'outdo', 'outlawed', 'outrun', 'outspoken', 'out of hand', '3 out of 4'].freeze

EVENT_REPLIES = ['in', 'in +1', 'in +123', 'in +99999999', 'IN', 'IN ', 'IN +6', 'IN     +322', 'IN +0',
                 'out', 'out +2', 'out +456', 'out +99999999', 'OUT', 'OUT ', 'OUT   +7', 'OUT +449', 'OUT +0'].freeze

NOT_KEYWORD_REPLIES = ['', ' ', '  ', 'create', 'make', 'text', 'rocks', 'event', 'sub', 'add event'].freeze

RSpec.describe Utils do
  include Utils

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

  describe '.collect_counts_for_message_id' do
    let(:sms_client) { class_double(SmsClient).as_stubbed_const }

    it 'returns the number of IN/OUT responses for a message' do
      message_id = 12345

      expect(sms_client).to receive(:sms_responses_for_message)
        .with(message_id: message_id)
        .and_return({ responses: [
          { response: 'IN' },
          { response: 'IN +2' },
          { response: 'IN + 1' },
          { response: 'IN +0' },
          { response: 'OUT' },
          { response: 'not a event reply' }
        ] }.as_json)

      expect(Utils.collect_counts_for_message_id(message_id)).to eq({ in: 7, out: 1 })
    end
  end
end
