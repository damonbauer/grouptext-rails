# frozen_string_literal: true

require 'chronic'

# Handles the various messages in the event flow
class MessagesController < ApplicationController
  include Utils
  include ActionView::Helpers::DateHelper

  # Executed when a user texts in "CREATE EVENT" to the number provided by BurstSMS.
  # This is triggered by a "Forward to URL" option on the "CREATE EVENT" keyword in BurstSMS.
  # This is the controller action that starts the entire chain.
  #
  # params:
  # * messages_params[:mobile] The phone number of the user who created the event
  def create_event
    lists_for_display = SmsClient.lists['lists'].map { |list| list['name'] }.join(', ')

    SmsClient.send_sms(
      message: "What list would you like to send to? Reply with one of: #{lists_for_display}",
      reply_callback: create_event_replies_url,
      to: messages_params[:mobile]
    )

    head :no_content
  end

  # Executed when the event creator responds with a list name to send an event to.
  # The corresponding URL for this action is set as a `reply_callback` to the message sent in #create_event
  #
  # params:
  # * messages_params[:mobile] The phone number of the user who created the event
  def create_event_replies
    matching_list_id = find_list_id_matching_reply

    unless matching_list_id
      SmsClient.send_sms(
        message: "Sorry, we couldn't find that list. Please try again.",
        reply_callback: create_event_replies_url,
        to: messages_params[:mobile]
      )

      return
    end

    SmsClient.send_sms(
      message: 'Got it. Now tell us the details. Reply with: SUBJECT;WHEN;WHERE;DEADLINE',
      reply_callback: "#{create_event_details_replies_url}?selected_list_id=#{matching_list_id}&event_creator=#{messages_params[:mobile]}",
      to: messages_params[:mobile]
    )

    head :no_content
  end

  # Executed when the event creator responds with event details.
  # This sends the event details to the list & queues up a job to collect responses.
  # The corresponding URL for this action is set as a `reply_callback` to the message sent in #create_event_replies
  #
  # params:
  # * messages_params[:selected_list_id] The list chosen by the user who created the event
  # * messages_params[:event_creator] The phone number of the user who created the event
  def create_event_details_replies
    subject, time, location, deadline = parse_event_details_response
    deadline ||= 'in 2 hours'

    message = SmsClient.send_sms_to_list(
      list_id: messages_params[:selected_list_id],
      message: "Who's IN for #{subject} #{time} at #{location}? Reply IN, IN +1/+2/+3/+#, OUT, or STOP. Deadline to reply is #{deadline}",
      reply_callback: "#{catch_all_url}?event_creator=#{messages_params[:event_creator]}"
    )

    SmsClient.send_sms(
      message: "Sent! Reply STATUS #{message['message_id']} to get current IN/OUT count",
      to: messages_params[:event_creator]
    )

    enqueue_event_replies_job(deadline: deadline, message_id: message['message_id'])

    head :no_content
  end

  def create_event_status
    message_id = Utils.strip_nondigits(messages_params[:response]).to_i

    in_count, out_count = Utils.collect_counts_for_message_id(message_id).values_at(:in, :out)

    event_response = SmsClient.read_sms(message_id: message_id)
    parsed_deadline = status_request_deadline(event_response)
    message_reply = if parsed_deadline.past?
                      "This event is in the past. There were #{in_count} in and #{out_count} out."
                    else
                      "Current status: #{in_count} are in, #{out_count} are out. Deadline is in #{distance_of_time_in_words_to_now(parsed_deadline)}."
                    end

    SmsClient.send_sms(
      message: message_reply,
      to: messages_params[:mobile]
    )

    head :no_content
  end

  # Executed as a callback to the message sent in EventRepliesJob#perform
  # The corresponding URL for this action is set as a `reply_callback` to the message sent in EventRepliesJob#perform
  #
  # params:
  # * messages_params[:response] The body of the SMS
  # * messages_params[:in_count] The number of "IN" responses collected
  # * messages_params[:selected_list_id] The list chosen by the user who created the event
  # * messages_params[:event_creator] The phone number of the user who created the event
  def event_decision_reply
    Rails.logger.info "event_decision_reply BEFORE RETURN: #{messages_params[:response]}"

    return unless acceptable_decision_response?

    Rails.logger.info "event_decision_reply AFTER RETURN: #{messages_params[:response]}"
    decision = messages_params[:response].downcase.strip

    Rails.logger.info "event_decision_reply decision: #{decision}"

    message_reply = if decision == DECISION_ON_RESPONSE.downcase
                      Rails.logger.debug 'event_decision_reply INSIDE IF'
                      "We have #{messages_params[:in_count]} committed to play, Game is ON!"
                    else
                      Rails.logger.debug 'event_decision_reply INSIDE ELSE'
                      'We do not have enough people committed to play. Game is OFF, enjoy your day!'
                    end

    Rails.logger.info "event_decision_reply send_sms_to_list: messages_params[:selected_list_id]: #{messages_params[:selected_list_id]}, message_reply: #{message_reply}, reply_callback: #{catch_all_url}?event_creator=#{messages_params[:event_creator]}"

    SmsClient.send_sms_to_list(list_id: messages_params[:selected_list_id],
                               message: message_reply,
                               reply_callback: "#{catch_all_url}?event_creator=#{messages_params[:event_creator]}")

    head :no_content
  end

  private

  # Used to find a BurstSMS list ID
  # Fetches all lists from BurstSMS, compares list names against user provided value
  # @return Integer|nil List ID that matches the list name (provided by user)
  def find_list_id_matching_reply
    list = SmsClient.lists['lists'].find { |l| l['name'].downcase == messages_params[:response].downcase.strip }
    list.nil? ? nil : list['id']
  end

  # Responsible for breaking event details response up by delimiter (whitespace removed)
  # @return [Array] Chunked event details
  def parse_event_details_response
    messages_params[:response].split(';').map!(&:strip)
  end

  # Responsible for parsing user provided deadline. If it can't be parsed, a fallback is returned
  # @param [String] deadline_from_sms The deadline provided by the user
  # @return Date|Time The parsed deadline, or a fallback (2 hours from now)
  def parsed_deadline(deadline_from_sms)
    Chronic.parse(deadline_from_sms) || 2.hours.from_now
  end

  # Responsible to queuing up the EventRepliesJob.
  # @param [String] deadline The deadline provided by the user
  # @param [Integer] message_id ID of the message to tie to the job
  # @return nil
  def enqueue_event_replies_job(deadline:, message_id:)
    EventRepliesJob.set(wait_until: parsed_deadline(deadline))
                   .perform_later(message_id: message_id,
                                  selected_list_id: messages_params[:selected_list_id],
                                  send_to: messages_params[:event_creator])
  end

  def acceptable_decision_response?
    [DECISION_ON_RESPONSE, DECISION_OFF_RESPONSE].map!(&:downcase).include?(messages_params[:response].downcase.strip)
  end

  # Used when a user requests the status of an event.
  # Gets the deadline from the original event & parses it relative to when the status request message was sent.
  # @param [Object] event_response The response body returned by SmsClient.read_sms
  # @return [DateTime] The deadline, offset by the time the status was requested
  def status_request_deadline(event_response)
    event_deadline = event_response['message'].split('Deadline to reply is ')[1]
    event_sent_at = DateTime.parse(event_response['send_at']).to_time
    Chronic.parse(event_deadline, { now: event_sent_at })
  end

  def messages_params
    params.permit!
  end
end
