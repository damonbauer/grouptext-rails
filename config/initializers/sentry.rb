Sentry.init do |config|
  config.breadcrumbs_logger = %i[sentry_logger active_support_logger http_logger]
  config.dsn = ENV['SENTRY_DSN']

  # To activate performance monitoring, set one of these options.
  # We recommend adjusting the value in production:
  config.traces_sample_rate = 1
  # or
  # config.traces_sampler = lambda do |context|
  #   true
  # end
end
