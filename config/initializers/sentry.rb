# frozen_string_literal: true

Sentry.init do |config|
  config.breadcrumbs_logger = %i[http_logger monotonic_active_support_logger sentry_logger]
  config.dsn = ENV['SENTRY_DSN']
  config.send_default_pii = true
  config.traces_sample_rate = 0.5
end
