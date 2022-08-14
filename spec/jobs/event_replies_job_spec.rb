# frozen_string_literal: true

RSpec.describe EventRepliesJob do
  describe '.perform' do
    let(:sms_client) { class_double(SmsClient).as_stubbed_const }
    let(:utils) { class_double(Utils).as_stubbed_const }

    it 'retrieves responses for the provided message and sends a message prompting the event creator for a decision' do
      ActiveJob::Base.queue_adapter = :test

      message_id = 99999
      message_sent_at = '2022-05-25 19:12:00'
      send_to = 55555555555
      in_count = 7
      out_count = 1

      expect(Utils).to receive(:collect_counts_for_timeframe)
        .with(start_date: message_sent_at)
        .and_return({ in: in_count, out: out_count })

      expect(sms_client).to receive(:send_sms)
        .with(message: "#{in_count} are in, #{out_count} are out. Reply #{DECISION_ON_RESPONSE} #{message_id} or #{DECISION_OFF_RESPONSE} #{message_id}",
              to: send_to)

      EventRepliesJob.perform_now(message_id: message_id, message_sent_at: message_sent_at, send_to: send_to)
    end
  end
end
