# frozen_string_literal: true

host = "#{ENV.fetch('HEROKU_APP_NAME')}.herokuapp.com"

# Set the correct protocol as SSL isn't configured in development or test.
protocol = Rails.env.production? ? 'https' : 'http'

Rails.application.routes.default_url_options.merge!(
  host: host,
  protocol: protocol
)

Rails.application.config.x.application_job.default_url_options = {
  host: host,
  protocol: protocol
}
