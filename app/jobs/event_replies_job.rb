# frozen_string_literal: true

# Responsible for messaging the event creator, asking for a decision at the provided deadline
class EventRepliesJob < ApplicationJob
  include Utils

  queue_as :default

  def perform(message_id:, message_sent_at:, send_to:)
    # formatted_end_date = Time.now.utc.strftime '%Y-%m-%d %H:%M:%S'
    in_count, out_count = Utils.collect_counts_for_timeframe(start_date: message_sent_at)
                               .values_at(:in, :out)

    SmsClient.send_sms(
      message: "#{in_count} are in, #{out_count} are out. Reply #{DECISION_ON_RESPONSE} #{message_id} or #{DECISION_OFF_RESPONSE} #{message_id}",
      to: send_to
    )
  end
end
