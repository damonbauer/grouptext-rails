# frozen_string_literal: true

ACCEPTABLE_REPLIES = %w[in out].freeze
API_ENDPOINT = 'https://api.transmitsms.com'
BOT_TOLL_FREE_NUMBER = '18448026390'
DECISION_OFF_RESPONSE = 'GAME CANCELED'
DECISION_ON_RESPONSE = 'GAME ON'
KEYWORD_REPLIES = [*ACCEPTABLE_REPLIES, 'stop', 'create event', 'subscribe'].freeze
MESSAGE_LIST_REPLIES = ['message list'].freeze
