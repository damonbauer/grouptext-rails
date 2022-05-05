# frozen_string_literal: true

RSpec.describe 'CatchAll' do
  let(:sms_client) { class_double(SmsClient).as_stubbed_const }

  describe 'GET /catch_all' do
    describe 'when params do not include a response' do
      it 'returns a 204 without sending a message' do
        expect(sms_client).not_to receive(:send_sms)

        get catch_all_url

        expect(response).to have_http_status(:no_content)
      end
    end

    describe 'when params include an empty response' do
      it 'returns a 204 without sending a message' do
        expect(sms_client).not_to receive(:send_sms)

        get catch_all_url({ response: '' })

        expect(response).to have_http_status(:no_content)
      end
    end

    describe 'when response starts with specific keywords' do
      KEYWORD_REPLIES.each do |reply|
        it 'returns a 204 without sending a message' do
          expect(sms_client).not_to receive(:send_sms)

          get catch_all_url(response: reply)

          expect(response).to have_http_status(:no_content)
        end
      end
    end

    describe 'when params do not include "is_catch_all_reply=true"' do
      it 'sends the message to the event creator' do
        event_creator = '55555555555'
        mobile = '99999999999'
        message = "Response from user with # #{mobile}"

        expect(sms_client).to receive(:send_sms).with(message: "Someone sent this reply to your message: \"#{message}\". You can ignore this reply, or reply to this message & we'll forward your response to them.",
                                                      to: event_creator,
                                                      reply_callback: "#{catch_all_url}?is_catch_all_reply=true&send_response_to=#{mobile}")

        get catch_all_url({ event_creator: event_creator, mobile: mobile, response: message })

        expect(response).to have_http_status(:no_content)
      end
    end

    describe 'when params include "is_catch_all_reply=true"' do
      it 'sends the message to the number in `send_response_to` param' do
        send_response_to = '55555555555'
        mobile = '99999999999'
        message = 'This is the response'

        expect(sms_client).to receive(:send_sms).with(message: message,
                                                      to: send_response_to,
                                                      reply_callback: "#{catch_all_url}?is_catch_all_reply=true&send_response_to=#{mobile}")

        get catch_all_url({ is_catch_all_reply: 'true',
                            mobile: mobile,
                            send_response_to: send_response_to,
                            response: message })

        expect(response).to have_http_status(:no_content)
      end
    end
  end
end
