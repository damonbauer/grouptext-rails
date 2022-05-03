# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.0.2'

gem 'chronic'
gem 'dotenv-rails'
gem 'faraday'
gem 'faraday-net_http'
gem 'oj'
gem 'puma', '~> 5.0'
gem 'rack-timeout'
gem 'rails', '~> 6.1.5'
gem 'rails_autoscale_agent'
gem 'redis'
gem 'sidekiq'

group :development do
  gem 'listen', '~> 3.3'
  gem 'rubocop', require: false
end

group :development, :test do
  gem 'fuubar'
  gem 'guard'
  gem 'guard-rspec'
  gem 'rspec-rails', '~> 6.0.0.rc1'
  gem 'simplecov'
  gem 'webmock'
end
