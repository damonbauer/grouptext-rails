# frozen_string_literal: true

RSpec.describe 'Donations' do
  let(:sms_client) { class_double(SmsClient).as_stubbed_const }

  describe 'POST /donation-webhook' do
    describe 'when response does not include `type` of "checkout.session.completed"' do
      it 'is a no-op' do
        expect(sms_client).not_to receive(:send_sms)

        params = build_webhook_response(600, 'Bob Jones', 'some.other.type')

        post donation_webhook_url, params: params.to_json

        expect(response).to have_http_status(:no_content)
      end
    end

    describe 'when response includes `type` of "checkout.session.completed"' do
      it 'sends a message to the admin with donor information' do
        expect(sms_client).to receive(:send_sms).with(message: 'Bob Jones donated $6',
                                                      to: ENV['ADMIN_MOBILE'])

        params = build_webhook_response(600, 'Bob Jones')

        post donation_webhook_url, params: params.to_json

        expect(response).to have_http_status(:no_content)
      end

      it 'sends a message to the admin with fallback donor information' do
        expect(sms_client).to receive(:send_sms).with(message: 'Someone donated $2',
                                                      to: ENV['ADMIN_MOBILE'])

        params = build_webhook_response(200, nil)

        post donation_webhook_url, params: params.to_json

        expect(response).to have_http_status(:no_content)
      end
    end
  end
end

# @param [Integer] amount The donation amount
# @param [String|nil] name The donor's name
# @param [String] type The webhook type: https://stripe.com/docs/api/events/types
# @return [Hash] Response body
def build_webhook_response(amount, name, type = 'checkout.session.completed')
  {
    data: {
      object: {
        amount_total: amount,
        customer_details: {
          name: name
        }
      }
    },
    type: type,
    format: :json
  }
end
