# frozen_string_literal: true

# Webhook to catch donations
class DonationsController < ApplicationController
  include Utils

  def webhook
    @parsed_response = Oj.load(request.body)

    return unless completed?

    SmsClient.send_sms(
      message: "#{donor_name} donated #{amount}",
      to: ENV['ADMIN_MOBILE']
    )
  end

  private

  def completed?
    @parsed_response['type'] == 'checkout.session.completed'
  end

  def donor_name
    @parsed_response['data']['object']['customer_details']['name'] || 'Someone'
  end

  def amount
    ActiveSupport::NumberHelper.number_to_currency(
      @parsed_response['data']['object']['amount_total'].fdiv(100),
      strip_insignificant_zeros: true
    )
  end
end
