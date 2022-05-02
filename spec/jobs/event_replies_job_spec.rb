# frozen_string_literal: true

RSpec.describe EventRepliesJob do
  describe '.perform' do
    let(:sms_client) { class_double('SmsClient').as_stubbed_const }

    it 'retrieves responses for the provided message and sends a message prompting the event creator for a decision' do
      ActiveJob::Base.queue_adapter = :test

      message_id = 99999
      selected_list_id = 123456
      send_to = 55555555555
      in_count = 3
      out_count = 1

      expect(sms_client).to receive(:sms_responses_for_message)
        .with(message_id: message_id)
        .and_return({ responses: [{ response: 'IN' }, { response: 'IN 2' }, { response: 'OUT' }] }.as_json)

      expect(sms_client).to receive(:send_sms)
        .with(message: "#{in_count} are in, #{out_count} are out. Reply #{DECISION_ON_RESPONSE} or #{DECISION_OFF_RESPONSE}",
              reply_callback: "#{event_decision_reply_url}?selected_list_id=#{selected_list_id}&in_count=#{in_count}&event_creator=#{send_to}",
              to: send_to)

      EventRepliesJob.perform_now(message_id: message_id, selected_list_id: selected_list_id, send_to: send_to)
    end
  end
end
