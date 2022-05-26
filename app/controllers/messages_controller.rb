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
    SmsClient.send_sms(
      message: "What list would you like to send to? Reply with one of: #{Utils.lists_for_display}",
      reply_callback: create_event_replies_url,
      to: messages_params[:mobile]
    )
  end

  # Executed when the event creator responds with a list name to send an event to.
  # The corresponding URL for this action is set as a `reply_callback` to the message sent in #create_event
  #
  # params:
  # * messages_params[:mobile] The phone number of the user who created the event
  def create_event_replies
    matching_list_id = Utils.find_list_id_matching_name(messages_params[:response])

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
      message: "Sent! Reply: STATUS #{message['message_id']} to get current IN/OUT count;\nNUDGE #{message['message_id']} to follow up with non-respondents",
      to: messages_params[:event_creator]
    )

    enqueue_event_replies_job(deadline: deadline, message_id: message['message_id'], message_sent_at: message['send_at'])
  end

  def create_event_status
    message_id = Utils.strip_nondigits(messages_params[:response])

    unless message_id
      SmsClient.send_sms(
        message: 'Please request a status with an ID.',
        to: messages_params[:mobile]
      )

      return
    end

    event_response = SmsClient.read_sms(message_id: message_id.to_i)
    parsed_deadline = status_request_deadline(event_response)
    in_count, out_count = Utils
                          .collect_counts_for_timeframe(start_date: event_response['send_at']).values_at(:in, :out)
    message_reply = if parsed_deadline.past?
                      "This event is in the past. There were #{in_count} in and #{out_count} out."
                    else
                      "Current status: #{in_count} are in, #{out_count} are out. Deadline is in #{distance_of_time_in_words_to_now(parsed_deadline)}."
                    end

    SmsClient.send_sms(
      message: message_reply,
      to: messages_params[:mobile]
    )
  end

  def nudge
    message_id = Utils.strip_nondigits(messages_params[:response])

    unless message_id
      SmsClient.send_sms(
        message: 'Please supply a message ID so we can nudge the correct people.',
        to: messages_params[:mobile]
      )

      return
    end

    audience = Utils.nudge_audience(message_id: message_id.to_i)
    audience_count = audience.split(',').length

    SmsClient.send_sms(to: audience,
                       message: "Hey there. We haven't gotten a reply from you yet. Reply IN, IN +1/+2/+3/+#, OUT, or STOP.",
                       reply_callback: "#{catch_all_url}?event_creator=#{messages_params[:mobile]}")

    SmsClient.send_sms(
      message: "Nudge sent to #{audience_count} people.",
      to: messages_params[:mobile]
    )
  end

  # Executed as a callback to the message sent in EventRepliesJob#perform
  # The corresponding URL for this action is set as a `reply_callback` to the message sent in EventRepliesJob#perform
  #
  # Sends the decision reply to everyone on the list who did not reply "OUT" to the event.
  #
  # params:
  # * messages_params[:response] The body of the SMS
  # * messages_params[:in_count] The number of "IN" responses collected
  # * messages_params[:event_message_id] The message ID that users replied IN/OUT to
  # * messages_params[:selected_list_id] The list chosen by the user who created the event
  # * messages_params[:event_creator] The phone number of the user who created the event
  def event_decision_reply
    return unless acceptable_decision_response?

    decision = messages_params[:response].downcase.strip
    audience = Utils.event_decision_audience(message_id: messages_params[:event_message_id])

    message_reply = if decision == DECISION_ON_RESPONSE.downcase
                      "We have #{messages_params[:in_count]} committed to play, Game is ON!"
                    else
                      'We do not have enough people committed to play. Game is OFF, enjoy your day!'
                    end

    SmsClient.send_sms(to: audience,
                       message: message_reply,
                       reply_callback: "#{catch_all_url}?event_creator=#{messages_params[:event_creator]}")
  end

  private

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
  # @param [String] message_sent_at ISO-8601 string when the message was sent
  # @return nil
  def enqueue_event_replies_job(deadline:, message_id:, message_sent_at:)
    EventRepliesJob.set(wait_until: parsed_deadline(deadline))
                   .perform_later(message_id: message_id,
                                  message_sent_at: message_sent_at,
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
