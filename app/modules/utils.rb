# frozen_string_literal: true

# Helper methods that don't belong in controllers or jobs
module Utils
  class << self
    def event_reply?(str)
      # https://rubular.com/r/iU3PDgY1ABPZHq
      str.downcase.strip.match?(/\A(in|out)\s*\+?\s*\d*\z/i)
    end

    def keyword_reply?(str)
      [*KEYWORD_REPLIES, *CARRIER_RESERVED_KEYWORDS].include?(str.downcase.strip)
    end

    # Responsible for counting the number of "IN" and "OUT" responses for an event
    # @param [Integer] message_id ID of the message to get counts for
    # @return { :in => Integer, :out => Integer }
    def collect_counts_for_message_id(message_id)
      api_response = SmsClient.sms_responses_for_message(message_id: message_id)
      responses = api_response['responses'] ||= []
      counts = { in: 0, out: 0 }

      event_replies(responses).each_with_object(counts) do |curr, acc|
        val = curr['response'].downcase.strip
        group = val.start_with?(ACCEPTABLE_REPLIES.first) ? :in : :out

        acc[group] += count(val)
      end
    end

    # @param [String] str The string to strip
    # @return [String] The number(s) found in the string
    def strip_nondigits(str)
      str.gsub(/\D/, '')
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
  end
end
