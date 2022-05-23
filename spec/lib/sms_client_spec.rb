# frozen_string_literal: true

RSpec.describe SmsClient do
  let(:headers) do
    { Authorization: 'Basic MTIzNDU2Nzg5MDpwYXNzd29yZA==' }
  end

  describe '.lists' do
    it 'fetches all lists for the account' do
      stub = stub_request(:get, "#{ENV['TRANSMIT_API_BASIC_AUTH_URL']}/get-lists.json")
             .with(headers: headers)

      SmsClient.lists

      expect(stub).to have_been_requested
    end
  end

  describe '.send_sms' do
    it 'sends a message to the provided number' do
      message = 'message'
      to = 55555555555
      stub = stub_request(:post, "#{ENV['TRANSMIT_API_BASIC_AUTH_URL']}/send-sms.json")
             .with(
               body: {
                 message: message,
                 from: BOT_TOLL_FREE_NUMBER,
                 to: to,
                 reply_callback: ''
               },
               headers: headers
             )

      SmsClient.send_sms(message: message, to: to)

      expect(stub).to have_been_requested
    end

    it 'sends a message to the provided number with provided reply_callback' do
      message = 'message'
      to = 55555555555
      reply_callback = 'https://example.com/reply_callback'

      stub = stub_request(:post, "#{ENV['TRANSMIT_API_BASIC_AUTH_URL']}/send-sms.json")
             .with(
               body: {
                 message: message,
                 from: BOT_TOLL_FREE_NUMBER,
                 to: to,
                 reply_callback: reply_callback
               },
               headers: headers
             )

      SmsClient.send_sms(message: message, to: to, reply_callback: reply_callback)

      expect(stub).to have_been_requested
    end
  end

  describe '.send_sms_to_list' do
    it 'sends a message to the provided list' do
      list_id = 1234567
      message = 'message'
      reply_callback = 'https://example.com/reply_callback'

      stub = stub_request(:post, "#{ENV['TRANSMIT_API_BASIC_AUTH_URL']}/send-sms.json")
             .with(
               body: {
                 message: message,
                 from: BOT_TOLL_FREE_NUMBER,
                 list_id: list_id,
                 reply_callback: reply_callback
               },
               headers: headers
             )

      SmsClient.send_sms_to_list(message: message, list_id: list_id, reply_callback: reply_callback)

      expect(stub).to have_been_requested
    end
  end

  describe '.sms_responses_for_message' do
    it 'retrieves responses for the provided message ID' do
      message_id = 98765

      stub = stub_request(:post, "#{ENV['TRANSMIT_API_BASIC_AUTH_URL']}/get-sms-responses.json")
             .with(
               body: { limit: 100, message_id: message_id },
               headers: headers
             )

      SmsClient.sms_responses_for_message(message_id: message_id)

      expect(stub).to have_been_requested
    end
  end

  describe '.read_sms' do
    it 'gets the details of a single message' do
      message_id = 98765
      stub = stub_request(:post, "#{ENV['TRANSMIT_API_BASIC_AUTH_URL']}/get-sms.json")
             .with(
               body: { message_id: message_id },
               headers: headers
             )

      SmsClient.read_sms(message_id: message_id)

      expect(stub).to have_been_requested
    end
  end

  describe '.recipients_for_message' do
    it 'gets a list of recipients for a message' do
      message_id = 98765
      stub = stub_request(:post, "#{ENV['TRANSMIT_API_BASIC_AUTH_URL']}/get-sms-sent.json")
             .with(
               body: { limit: 100, list_id: '', message_id: message_id },
               headers: headers
             )

      SmsClient.recipients_for_message(message_id: message_id)

      expect(stub).to have_been_requested
    end
  end

  describe 'when a request fails' do
    let(:sentry) { class_double(Sentry).as_stubbed_const }

    it 'logs an exception' do
      expect(sentry).to receive(:capture_exception).with(Faraday::UnauthorizedError)

      stub_request(:get, "#{ENV['TRANSMIT_API_BASIC_AUTH_URL']}/get-lists.json")
        .with(headers: headers)
        .to_return({ status: 401 })

      SmsClient.lists
    end
  end
end
