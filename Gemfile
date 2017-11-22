# frozen_string_literal: true

source 'https://rubygems.org'

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

# Specify your gem's dependencies in elastic-apm.gemspec
gemspec

gem 'pry'
gem 'rack-test'
gem 'rspec'
gem 'rubocop'
gem 'sequel'
gem 'sqlite3'
gem 'timecop'
gem 'webmock', require: 'webmock/rspec'
gem 'yard'

gem 'fakeredis', require: nil,
  github: 'guilleiguaran/fakeredis' # needs master right now
gem 'redis', require: nil

framework, *version = ENV.fetch('FRAMEWORK', 'rails').split('-')
version = version.join('-')

case version
when 'master'
  gem framework, github: "#{framework}/#{framework}"
when /.+/
  gem framework, version
else
  gem framework
end
