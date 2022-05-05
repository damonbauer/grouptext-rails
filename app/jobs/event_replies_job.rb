# frozen_string_literal: true

# Responsible for messaging the event creator, asking for a decision at the provided deadline
class EventRepliesJob < ApplicationJob
  include Utils

  queue_as :default

  def perform(message_id:, selected_list_id:, send_to:)
    in_count, out_count = Utils.collect_counts_for_message_id(message_id).values_at(:in, :out)

    SmsClient.send_sms(
      message: "#{in_count} are in, #{out_count} are out. Reply #{DECISION_ON_RESPONSE} or #{DECISION_OFF_RESPONSE}",
      reply_callback: "#{event_decision_reply_url}?selected_list_id=#{selected_list_id}&in_count=#{in_count}&event_creator=#{send_to}",
      to: send_to
    )
  end
end
