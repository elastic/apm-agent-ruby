# frozen_string_literal: true

source 'https://rubygems.org'

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

# Tools
gem 'bootsnap', require: false
gem 'cucumber', require: false
gem 'pry'
gem 'rack-test'
gem 'rspec', '~> 3'
gem 'rspec-its'
gem 'rubocop', require: nil
gem 'rubocop-performance', require: nil
gem 'timecop'
gem 'webmock'

# Integrations
gem 'aws-sdk-sqs', require: nil
gem 'elasticsearch', require: nil
gem 'fakeredis', require: nil
gem 'faraday', require: nil
gem 'grpc' if !defined?(JRUBY_VERSION) && RUBY_VERSION < '2.7'
gem 'json-schema', require: nil
gem 'mongo', require: nil
gem 'opentracing', require: nil
gem 'rake', require: nil
gem 'resque', require: nil
gem 'sequel', require: nil
gem 'shoryuken', require: nil
gem 'sidekiq', require: nil
gem 'simplecov', require: false
gem 'simplecov-cobertura', require: false
gem 'sneakers', '~> 2.12', require: nil
gem 'yard', require: nil
gem 'yarjuf'

if RUBY_PLATFORM == 'java'
  gem 'activerecord-jdbcsqlite3-adapter'
  gem 'jdbc-sqlite3'
else
  gem 'sqlite3'
end

## Install Framework
GITHUB_REPOS = {
  'grape' => 'ruby-grape/grape',
  'rails' => 'rails/rails',
  'sinatra' => 'sinatra/sinatra'
}.freeze

#                new               || legacy           || default
env_frameworks = ENV['FRAMEWORKS'] || ENV['FRAMEWORK'] || ''
parsed_frameworks = env_frameworks.split(',')
frameworks_versions = parsed_frameworks.inject({}) do |frameworks, str|
  framework, *version = str.split('-')
  frameworks.merge(framework => version.join('-'))
end

frameworks_versions.each do |framework, version|
  case version
  when 'master'
    gem framework, github: GITHUB_REPOS.fetch[framework]
  when /.+/
    gem framework, "~> #{version}.0"
  else
    gem framework
  end
end

if frameworks_versions.key?('rails')
  unless frameworks_versions['rails'] =~ /^(master|6)/
    gem 'delayed_job', require: nil
  end
end

group :bench do
  gem 'ruby-prof', require: nil, platforms: %i[ruby]
  gem 'stackprof', require: nil, platforms: %i[ruby]
end

gemspec
