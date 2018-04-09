# frozen_string_literal: true

source 'https://rubygems.org'

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

gemspec

gem 'elasticsearch'
gem 'fakeredis', require: nil,
  github: 'guilleiguaran/fakeredis' # needs master right now
gem 'json-schema'
gem 'pry'
gem 'rack-test'
gem 'redis', require: nil
gem 'rspec'
gem 'rubocop'
gem 'sequel'
gem 'sidekiq'
gem 'timecop'
gem 'webmock'
gem 'yard'

if RUBY_PLATFORM == 'java'
  gem 'jdbc-sqlite3'
else
  gem 'sqlite3'
end

framework, *version = ENV.fetch('FRAMEWORK', 'rails').split('-')
version = version.join('-')

case version
when 'master'
  gem framework, github: "#{framework}/#{framework}"
when /.+/
  gem framework, "~> #{version}.0"
else
  gem framework
end

# doesn't work with Rails master, so skip testing
gem 'delayed_job' # unless [framework, version] == %w[rails master]

gem 'rails' if framework == 'sinatra'
gem 'sinatra' if framework == 'rails'
