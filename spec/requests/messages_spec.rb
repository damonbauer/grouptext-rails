# frozen_string_literal: true

RSpec.describe 'Messages' do
  let(:sms_client) { class_double(SmsClient).as_stubbed_const }
  let(:event_replies_job) { class_double(EventRepliesJob).as_stubbed_const }

  describe 'GET /create_event' do
    describe 'when params do not include a response' do
      it 'returns a 204 without sending a message' do
        mobile = 55555555555

        expect(sms_client).to receive(:lists).and_return({ lists: [{ name: 'List Name A' }, { name: 'List Name B' }] }.as_json)

        expect(sms_client).to receive(:send_sms).with(message: 'What list would you like to send to? Reply with one of: List Name A, List Name B',
                                                      reply_callback: create_event_replies_url,
                                                      to: mobile.to_s)

        get create_event_url({ mobile: mobile })

        expect(response).to have_http_status(:no_content)
      end
    end
  end

  describe 'GET /create_event_status' do
    let(:utils) { class_double(Utils).as_stubbed_const }

    describe 'when the event is in the past' do
      it 'sends an "event in the past" message back' do
        # force date to 05/15/2022
        # deadline is "in 5 days"; message was sent at "05/05/2022"
        travel_to Time.utc(2022, 5, 15, 6, 45, 33)
        message_id = 123456789
        status_message_body = "STATUS #{message_id}"
        event_message_body = "Who's IN for SUBJECT TIME at LOCATION? Reply IN, IN +1/+2/+3/+#, OUT, or STOP. Deadline to reply is in 5 days"
        mobile = 55555555555
        in_count = 2
        out_count = 1

        expect(Utils).to receive(:strip_nondigits)
          .with(status_message_body)
          .and_return(message_id)

        expect(Utils).to receive(:collect_counts_for_message_id)
          .with(message_id)
          .and_return({ in: in_count, out: out_count })

        expect(sms_client).to receive(:read_sms)
          .with(message_id: message_id)
          .and_return({ message: event_message_body, "send_at": '2022-05-05 06:45:33' }.as_json)

        expect(sms_client).to receive(:send_sms).with(message: "This event is in the past. There were #{in_count} in and #{out_count} out.",
                                                      to: mobile.to_s)

        get create_event_status_url({ mobile: mobile, response: status_message_body })

        expect(response).to have_http_status(:no_content)
      end
    end

    describe 'when the event is in the future' do
      it 'sends a status message back' do
        # force date to 05/05/2022 10:45:33
        # event deadline is "in 8 hours";
        # status message request was sent at "05/05/2022 08:45:33" (2 hours later) leaving 6 hours until deadline
        travel_to Time.utc(2022, 5, 5, 10, 45, 33)

        message_id = 123456789
        status_message_body = "STATUS #{message_id}"
        event_message_body = "Who's IN for SUBJECT TIME at LOCATION? Reply IN, IN +1/+2/+3/+#, OUT, or STOP. Deadline to reply is in 8 hours"
        mobile = 55555555555
        in_count = 2
        out_count = 1

        expect(Utils).to receive(:strip_nondigits)
          .with(status_message_body)
          .and_return(message_id)

        expect(Utils).to receive(:collect_counts_for_message_id)
          .with(message_id)
          .and_return({ in: in_count, out: out_count })

        expect(sms_client).to receive(:read_sms)
          .with(message_id: message_id)
          .and_return({ message: event_message_body, "send_at": '2022-05-05 08:45:33' }.as_json) # send_at is 2 hours after `travel_to` call

        expect(sms_client).to receive(:send_sms).with(message: "Current status: #{in_count} are in, #{out_count} are out. Deadline is in about 6 hours.",
                                                      to: mobile.to_s)

        get create_event_status_url({ mobile: mobile, response: status_message_body })

        expect(response).to have_http_status(:no_content)
      end
    end
  end

  describe 'GET /create_event_replies' do
    describe 'when the user provided list cannot be found' do
      it 'sends a message back asking to try again' do
        mobile = 55555555555
        user_response = 'Non matching list name'

        expect(sms_client).to receive(:lists).and_return({ lists: [{ id: 12345, name: 'List Name A' }, { id: 54321, name: 'List Name B' }] }.as_json)
        expect(sms_client).to receive(:send_sms).with(message: "Sorry, we couldn't find that list. Please try again.",
                                                      reply_callback: create_event_replies_url,
                                                      to: mobile.to_s)

        get create_event_replies_url({ mobile: mobile, response: user_response })

        expect(response).to have_http_status(:no_content)
      end
    end

    it 'sends a message back asking for event details' do
      mobile = 55555555555
      matching_list_id = 12345
      user_response = 'List Name A'

      expect(sms_client).to receive(:lists).and_return({ lists: [{ id: 12345, name: 'List Name A' }, { id: 54321, name: 'List Name B' }] }.as_json)
      expect(sms_client).to receive(:send_sms).with(message: 'Got it. Now tell us the details. Reply with: SUBJECT;WHEN;WHERE;DEADLINE',
                                                    reply_callback: "#{create_event_details_replies_url}?selected_list_id=#{matching_list_id}&event_creator=#{mobile}",
                                                    to: mobile.to_s)

      get create_event_replies_url({ mobile: mobile, response: user_response })

      expect(response).to have_http_status(:no_content)
    end
  end

  describe 'GET /create_event_details_replies' do
    describe 'when the event deadline is not provided' do
      it 'parses response, sends a message to the provided list with a fallback deadline, enqueues EventRepliesJob' do
        freeze_time

        event_creator = '55555555555'
        message_id = 99999
        selected_list_id = '12345'

        expect(sms_client).to receive(:send_sms_to_list).with(
          list_id: selected_list_id,
          message: "Who's IN for SUBJECT TIME at LOCATION? Reply IN, IN +1/+2/+3/+#, OUT, or STOP. Deadline to reply is in 2 hours",
          reply_callback: "#{catch_all_url}?event_creator=#{event_creator}"
        ).and_return({ message_id: message_id }.as_json)

        expect(sms_client).to receive(:send_sms).with(
          message: "Sent! Reply STATUS #{message_id} to get current IN/OUT count",
          to: event_creator
        )

        expect(event_replies_job).to receive_message_chain(:set, :perform_later).with(wait_until: 2.hours.from_now).with(message_id: message_id, selected_list_id: selected_list_id, send_to: event_creator)

        get create_event_details_replies_url({ event_creator: event_creator,
                                               response: 'SUBJECT;TIME;LOCATION',
                                               selected_list_id: selected_list_id })

        expect(response).to have_http_status(:no_content)
      end
    end

    it 'parses response, sends a message to the provided list with a provided deadline, enqueues EventRepliesJob' do
      freeze_time

      event_creator = '55555555555'
      message_id = 99999
      selected_list_id = '12345'

      expect(sms_client).to receive(:send_sms_to_list).with(
        list_id: selected_list_id,
        message: "Who's IN for SUBJECT TIME at LOCATION? Reply IN, IN +1/+2/+3/+#, OUT, or STOP. Deadline to reply is in 5 days",
        reply_callback: "#{catch_all_url}?event_creator=#{event_creator}"
      ).and_return({ message_id: message_id }.as_json)

      expect(sms_client).to receive(:send_sms).with(
        message: "Sent! Reply STATUS #{message_id} to get current IN/OUT count",
        to: event_creator
      )

      expect(event_replies_job).to receive_message_chain(:set, :perform_later)
        .with(wait_until: 5.days.from_now)
        .with(message_id: message_id,
              selected_list_id: selected_list_id,
              send_to: event_creator)

      get create_event_details_replies_url({ event_creator: event_creator,
                                             response: 'SUBJECT;TIME;LOCATION;in 5 days',
                                             selected_list_id: selected_list_id })

      expect(response).to have_http_status(:no_content)
    end
  end

  describe 'GET /event_decision_reply' do
    describe 'when event creator responds with DECISION_ON_RESPONSE' do
      it 'sends the appropriate message to the selected list' do
        event_creator = '55555555555'
        selected_list_id = '12345'
        in_count = 9

        expect(sms_client).to receive(:send_sms_to_list).with(
          list_id: selected_list_id,
          message: "We have #{in_count} committed to play, Game is ON!",
          reply_callback: "#{catch_all_url}?event_creator=#{event_creator}"
        )

        get event_decision_reply_url({
                                       event_creator: event_creator,
                                       in_count: in_count,
                                       response: DECISION_ON_RESPONSE,
                                       selected_list_id: selected_list_id
                                     })
        expect(response).to have_http_status(:no_content)
      end
    end

    describe 'when event creator responds with DECISION_OFF_RESPONSE' do
      it 'sends the appropriate message to the selected list' do
        event_creator = '55555555555'
        selected_list_id = '12345'
        in_count = 9

        expect(sms_client).to receive(:send_sms_to_list).with(
          list_id: selected_list_id,
          message: 'We do not have enough people committed to play. Game is OFF, enjoy your day!',
          reply_callback: "#{catch_all_url}?event_creator=#{event_creator}"
        )

        get event_decision_reply_url({
                                       event_creator: event_creator,
                                       in_count: in_count,
                                       response: DECISION_OFF_RESPONSE,
                                       selected_list_id: selected_list_id
                                     })
        expect(response).to have_http_status(:no_content)
      end
    end
  end
end
