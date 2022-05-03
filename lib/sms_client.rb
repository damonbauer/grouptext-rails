# frozen_string_literal: true

require 'faraday'
require 'faraday/net_http'

# Responsible for communicating with the BurstSMS/TransmitSMS API
class SmsClient
  def initialize; end

  class << self
    def lists
      request(
        http_method: :get,
        endpoint: 'get-lists.json'
      )
    end

    def send_sms(message:, to:, reply_callback: '')
      request(
        http_method: :post,
        endpoint: 'send-sms.json',
        params: {
          message: message,
          from: BOT_TOLL_FREE_NUMBER,
          to: to,
          reply_callback: reply_callback
        }
      )
    end

    def send_sms_to_list(list_id:, message:, reply_callback: '')
      request(
        http_method: :post,
        endpoint: 'send-sms.json',
        params: {
          from: BOT_TOLL_FREE_NUMBER,
          list_id: list_id,
          message: message,
          reply_callback: reply_callback
        }
      )
    end

    def sms_responses_for_message(message_id:)
      request(
        http_method: :post,
        endpoint: 'get-sms-responses.json',
        params: {
          message_id: message_id
        }
      )
    end

    private

    def client
      @client ||= Faraday.new(ENV['TRANSMIT_API_BASIC_AUTH_URL']) do |client|
        client.request :url_encoded
        client.adapter :net_http
        client.request :authorization, :basic, ENV['TRANSMIT_API_BASIC_AUTH_USERNAME'], ENV['TRANSMIT_API_BASIC_AUTH_PASSWORD']
      end
    end

    def request(http_method:, endpoint:, params: {})
      response = client.public_send(http_method, endpoint, params)
      Oj.load(response.body)
    end
  end
end
