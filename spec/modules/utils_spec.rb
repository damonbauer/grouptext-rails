# frozen_string_literal: true

NOT_EVENT_REPLIES = ['', ' ', '  ', '1', '123', '!!', 'hello', 'mug',
                     'in!', 'in in', 'intense', 'interest', 'individual', 'in case you thought', 'in 3 instances', 'just in case',
                     'out!', 'out out', 'outdo', 'outlawed', 'outrun', 'outspoken', 'out of hand', '3 out of 4'].freeze

EVENT_REPLIES = ['in', 'in +1', 'in +123', 'in +99999999', 'IN', 'IN ', 'IN +6', 'IN     +322', 'IN +0',
                 'out', 'out +2', 'out +456', 'out +99999999', 'OUT', 'OUT ', 'OUT   +7', 'OUT +449', 'OUT +0'].freeze

NOT_KEYWORD_REPLIES = ['', ' ', '  ', 'create', 'make', 'text', 'rocks', 'event', 'sub', 'add event'].freeze

RSpec.describe Utils do
  include Utils

  describe '.event_reply?' do
    NOT_EVENT_REPLIES.each do |reply|
      it "properly identifies \"#{reply}\" as `false`" do
        expect(event_reply?(reply)).to be(false)
      end
    end

    EVENT_REPLIES.each do |reply|
      it "properly identifies \"#{reply}\" as `true`" do
        expect(event_reply?(reply)).to be(true)
      end
    end
  end

  describe '.keyword_reply?' do
    NOT_KEYWORD_REPLIES.each do |reply|
      it "properly identifies \"#{reply}\" as `false`" do
        expect(keyword_reply?(reply)).to be(false)
      end
    end

    [*KEYWORD_REPLIES, *CARRIER_RESERVED_KEYWORDS].each do |reply|
      it "properly identifies \"#{reply}\" as `true`" do
        expect(keyword_reply?(reply)).to be(true)
      end
    end
  end
end
