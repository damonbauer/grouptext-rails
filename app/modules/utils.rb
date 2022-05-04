module Utils
  def event_reply?(str)
    # https://rubular.com/r/iU3PDgY1ABPZHq
    str.downcase.strip.match?(/\A(in|out)\s*\+?\s*\d*\z/i)
  end

  def keyword_reply?(str)
    [*KEYWORD_REPLIES, *CARRIER_RESERVED_KEYWORDS].include?(str.downcase.strip)
  end
end
