module Utils
  def event_reply?(str)
    # https://rubular.com/r/rHK1ewNZmk1Jlr
    str.downcase.strip.match?(/\A(in|out)\s*\d*\z/i)
  end

  def keyword_reply?(str)
    [*KEYWORD_REPLIES, *CARRIER_RESERVED_KEYWORDS].include?(str.downcase.strip)
  end
end
