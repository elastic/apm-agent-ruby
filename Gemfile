# frozen_string_literal: true

source 'https://rubygems.org'

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

gemspec

gem 'pry'
gem 'rack-test'
gem 'rspec'
gem 'rspec-its'
gem 'rubocop', require: nil
gem 'timecop'
gem 'webmock'

gem 'elasticsearch', require: nil
gem 'fakeredis', require: nil
gem 'json-schema', require: nil
gem 'mongo', require: nil
gem 'rake', require: nil
# gem 'redis', require: nil
gem 'sequel', require: nil
gem 'sidekiq', require: nil

gem 'yard', require: nil
gem 'yarjuf', require: nil

if RUBY_PLATFORM == 'java'
  gem 'jdbc-sqlite3', require: nil
else
  gem 'sqlite3', require: nil
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
  gem 'ruby-prof', require: nil, platforms: %i[ruby]
  gem 'stackprof', require: nil, platforms: %i[ruby]
end
