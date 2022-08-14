# frozen_string_literal: true

require 'date'

# Helper methods that don't belong in controllers or jobs
module Utils
  class << self
    def event_reply?(str)
      # https://rubular.com/r/EKTetHLgv5JZYL
      str.downcase.strip.match?(/\A(in|out)[.!]*\s*\+?\s*\d*\z/i)
    end

    def keyword_reply?(str)
      [*KEYWORD_REPLIES, *CARRIER_RESERVED_KEYWORDS].include?(str.downcase.strip)
    end

    # Responsible for counting the number of "IN" and "OUT" responses for an event
    # @return { :in => Integer, :out => Integer }
    # @param [String] start_date The start of the date range to look for responses
    # @param [String] end_date The end of the date range to look for responses
    def collect_counts_for_timeframe(start_date: nil, end_date: nil)
      api_response = SmsClient.sms_responses_for_timeframe(start_date: start_date, end_date: end_date)
      responses = api_response['responses'] ||= []
      counts = { in: 0, out: 0 }

      event_replies(responses).each_with_object(counts) do |curr, acc|
        val = curr['response'].downcase.strip
        group = val.start_with?(ACCEPTABLE_REPLIES.first) ? :in : :out

        acc[group] += count(val)
      end
    end

    # Responsible for getting the phones numbers of those who did not reply "OUT" for an event
    # @param [String] message_id ID of the message to get counts for
    # @return [String] A comma-delimited string of numbers who replied "IN" or did not reply
    def event_decision_audience(message_id:)
      event_recipients = message_recipients_numbers(message_id: message_id)
      message = SmsClient.read_sms(message_id: message_id)
      out_numbers = out_numbers(start_date: message['send_at'])
      (event_recipients - out_numbers).join(',')
    end

    # Responsible for getting the phones numbers of those who have not replied to an event
    # @param [String] message_id ID of the message to nudge for
    # @return [String] A comma-delimited string of numbers who have not replied
    def nudge_audience(message_id:)
      event_recipients = message_recipients_numbers(message_id: message_id)
      message = SmsClient.read_sms(message_id: message_id)
      event_respondents = event_respondents_numbers(start_date: message['send_at'])
      (event_recipients - event_respondents).join(',')
    end

    # @param [String] str The string to strip
    # @return [String] The number(s) found in the string
    def strip_nondigits(str)
      str.gsub(/\D/, '')
    end

    # @param [String] str The string to strip
    # @return [String] The string with all digits removed
    def strip_digits(str)
      str.gsub(/\d/, '')
    end

    # Fetch & display lists for the account
    # @return [String] A concatenated string of list names
    def lists_for_display
      SmsClient.lists['lists'].map { |list| list['name'] }.join(', ')
    end

    # Used to find a BurstSMS list ID
    # Fetches all lists from BurstSMS, compares list names against user provided value
    # @return Integer|Nil List ID that matches the list name (provided by user)
    def find_list_id_matching_name(list_name)
      list = SmsClient.lists['lists'].find { |l| l['name'].downcase == list_name.downcase.strip }
      list.nil? ? nil : list['id']
    end

    private

    # Takes a string & removes anything that's not a digit.
    # If the resulting string is empty, returns `1`. Otherwise, returns 1 + `#` found in suffix.
    # @param [String] str The string to collect counts from. Examples: "IN", "IN +2", "IN +4", "OUT", "OUT +3"
    # @return [Integer]
    def count(str)
      seed = 1
      match = strip_nondigits(str)
      match.empty? ? seed : seed + match.to_i
    end

    # Filters array of `responses` (objects) based on if the response object has a key of `response` with a value
    # that is an `event_reply?`.
    # @param unfiltered_response Array<Object> An array of response objects
    # @return Array<Object> An array of response objects that match
    def event_replies(unfiltered_response)
      unfiltered_response.select { |response| event_reply?(response['response']) }
    end

    # Responsible for getting the phones numbers of those who replied "OUT" for an event
    # @param [String] start_date When to start looking for messages
    # @return String[] An array of numbers who replied "OUT"
    def out_numbers(start_date:)
      responses = timeframe_responses(start_date: start_date)

      collection = event_replies(responses)
                   .select { |reply| reply['response'].downcase.strip.start_with?(ACCEPTABLE_REPLIES.second) }

      collect_numbers(collection)
    end

    # Responsible for getting the phones numbers of those who replied to a CREATE EVENT message with "IN" or "OUT"
    # @param [String] start_date When to start looking for messages
    # @return String[] An array of respondents numbers
    def event_respondents_numbers(start_date:)
      responses = timeframe_responses(start_date: start_date)
      collection = event_replies(responses)
      collect_numbers(collection)
    end

    def timeframe_responses(start_date: nil, end_date: nil)
      api_response = SmsClient.sms_responses_for_timeframe(start_date: start_date, end_date: end_date)
      api_response['responses'] ||= []
    end

    # Responsible for getting the phones numbers of those who received a CREATE EVENT message
    # @param [String] message_id ID of the message to recipients for
    # @return String[] An array of recipients numbers
    def message_recipients_numbers(message_id:)
      api_response = SmsClient.recipients_for_message(message_id: message_id)
      recipients = api_response['recipients'] ||= []

      collect_numbers(recipients)
    end

    def collect_numbers(collection)
      collection.map { |el| el['msisdn'] }
    end
  end
end
