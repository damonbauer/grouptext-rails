# frozen_string_literal: true

require 'chronic'

# Handles the various messages in the event flow
class MessagesController < ApplicationController
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

    enqueue_event_replies_job(deadline: deadline, message_id: message['message_id'])

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
    return unless acceptable_decision_response?

    message = if messages_params[:response].downcase.strip == DECISION_ON_RESPONSE.downcase
                "We have #{messages_params[:in_count]} committed to play, Game is ON!"
              elsif messages_params[:response].downcase.strip == DECISION_OFF_RESPONSE.downcase
                'We do not have enough people committed to play. Game is OFF, enjoy your day!'
              end

    SmsClient.send_sms_to_list(list_id: messages_params[:selected_list_id],
                               message: message,
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

  def messages_params
    params.permit!
  end
end
