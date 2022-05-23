# frozen_string_literal: true

RSpec.describe EventRepliesJob do
  describe '.perform' do
    let(:sms_client) { class_double(SmsClient).as_stubbed_const }
    let(:utils) { class_double(Utils).as_stubbed_const }

    it 'retrieves responses for the provided message and sends a message prompting the event creator for a decision' do
      ActiveJob::Base.queue_adapter = :test

      message_id = 99999
      selected_list_id = 123456
      send_to = 55555555555
      in_count = 7
      out_count = 1

      expect(Utils).to receive(:collect_counts_for_message_id)
        .with(message_id)
        .and_return({ in: in_count, out: out_count })

      expect(sms_client).to receive(:send_sms)
        .with(message: "#{in_count} are in, #{out_count} are out. Reply #{DECISION_ON_RESPONSE} or #{DECISION_OFF_RESPONSE}",
              reply_callback: "http://#{ENV['HEROKU_APP_NAME']}.herokuapp.com/event_decision_reply?selected_list_id=#{selected_list_id}&event_message_id=#{message_id}&in_count=#{in_count}&event_creator=#{send_to}",
              to: send_to)

      EventRepliesJob.perform_now(message_id: message_id, selected_list_id: selected_list_id, send_to: send_to)
    end
  end
end
