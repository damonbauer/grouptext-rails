# frozen_string_literal: true

# Responsible for messaging the event creator, asking for a decision at the provided deadline
class EventRepliesJob < ApplicationJob
  include Utils

  queue_as :default

  def perform(message_id:, selected_list_id:, send_to:)
    @api_response = SmsClient.sms_responses_for_message(message_id: message_id)
    in_count, out_count = collect_counts.values_at(:in, :out)

    SmsClient.send_sms(
      message: "#{in_count} are in, #{out_count} are out. Reply #{DECISION_ON_RESPONSE} or #{DECISION_OFF_RESPONSE}",
      reply_callback: "#{event_decision_reply_url}?selected_list_id=#{selected_list_id}&in_count=#{in_count}&event_creator=#{send_to}",
      to: send_to
    )
  end

  private

  # Takes a string starting with "IN" or "OUT" that also potentially has an integer suffix.
  # Removes anything that's not a digit.
  # If the resulting string is empty, returns `1`. Otherwise, returns `#` found in suffix.
  # @param [String] str The string to collect counts from. Examples: "IN", "IN 2", "IN 4", "OUT", "OUT 3"
  # @return [Integer]
  def count(str)
    match = str.gsub(/\D/, '')
    match.empty? ? 1 : match.to_i
  end

  # Filters `responses` array based on if the response starts with a value in `ACCEPTABLE_REPLIES`
  # @return Array<Object> An array of response objects
  def filtered_responses
    responses = @api_response['responses'] ||= []
    responses.select { |response| event_reply?(response['response']) }
  end

  # Responsible for counting the number of "IN" and "OUT" responses
  # @return { :in => Integer, :out => Integer }
  def collect_counts
    counts = { in: 0, out: 0 }

    filtered_responses.each_with_object(counts) do |curr, acc|
      val = curr['response'].downcase.strip
      group = val.start_with?(ACCEPTABLE_REPLIES.first) ? :in : :out

      acc[group] += count(val)
    end

    counts
  end
end
