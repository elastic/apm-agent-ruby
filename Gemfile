# frozen_string_literal: true

source 'https://rubygems.org'

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

gemspec

gem 'elasticsearch'
gem 'fakeredis', require: nil
gem 'json-schema'
gem 'mongo'
gem 'pry'
gem 'rack-test'
gem 'redis', require: nil
gem 'rspec'
gem 'rspec-its'
gem 'rubocop'
gem 'sequel'
gem 'sidekiq'
gem 'timecop'
gem 'webmock'
gem 'yard'
gem 'yarjuf'

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

group :bench do
  gem 'ruby-prof', platforms: %i[ruby]
  gem 'stackprof', platforms: %i[ruby]
end
