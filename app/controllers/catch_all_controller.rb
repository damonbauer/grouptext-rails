# frozen_string_literal: true

class CatchAllController < ApplicationController
  def handle
    # If the response looks to be a "keyword reply" (such as "IN", or "STOP"), ignore this reply.
    return if empty_response? || keyword_reply?

    if catch_all_reply?
      # The event creator can either choose to ignore this message, or
      # they can reply to the message, in which case we'll forward their message back to the person who
      # replied to the event message.
      SmsClient.send_sms(
        message: catch_all_params[:response],
        to: catch_all_params[:send_response_to],
        reply_callback: "#{catch_all_url}?is_catch_all_reply=true&send_response_to=#{catch_all_params[:mobile]}"
      )
      return
    else
      # Otherwise, forward this message on to the user who created the event.
      #
      # The event creator can either choose to ignore this message, or
      # they can reply to the message, in which case we'll forward their message back to the person who
      # replied to the event message.
      SmsClient.send_sms(
        message: "Someone sent this reply to your message: \"#{catch_all_params[:response]}\". You can ignore this reply, or reply to this message & we'll forward your response to them.",
        to: catch_all_params[:event_creator],
        reply_callback: "#{catch_all_url}?is_catch_all_reply=true&send_response_to=#{catch_all_params[:mobile]}"
      )
    end

    head :no_content
  end

  private

  def empty_response?
    catch_all_params[:response].nil? || catch_all_params[:response].empty?
  end

  def catch_all_reply?
    catch_all_params[:is_catch_all_reply] == 'true'
  end

  # Determines if the value in catch_all_params[:response] is a "keyword reply"
  # @return [Boolean]
  def keyword_reply?
    return unless catch_all_params[:response]

    # TODO: THIS IS WRONG
    #
    # KEYWORD_REPLIES = [*ACCEPTABLE_REPLIES, 'stop', 'create event', 'subscribe'].freeze
    catch_all_params[:response].downcase.strip.start_with?(*KEYWORD_REPLIES)
  end

  def catch_all_params
    params.permit!
  end
end
