# frozen_string_literal: true

source 'https://rubygems.org'

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

gem 'rack-test'
gem 'rspec'
gem 'rspec-its'
gem 'rubocop', require: nil
gem 'timecop'
gem 'webmock'

gem 'elasticsearch', require: nil
gem 'fakeredis', require: nil
gem 'faraday', require: nil
gem 'json-schema', require: nil
gem 'mongo', require: nil
gem 'opentracing', require: nil
gem 'rake', require: nil
gem 'sequel', require: nil
gem 'sidekiq', require: nil
gem 'simplecov', require: false, group: :test
gem 'simplecov-cobertura', require: false, group: :test
gem 'yard', require: nil
gem 'yarjuf'

if RUBY_PLATFORM == 'java'
  gem 'jdbc-sqlite3'
else
  gem 'sqlite3'
end

## Install Framework
GITHUB_REPOS = { 'grape' => 'ruby-grape/grape'}

frameworks = ENV.fetch('FRAMEWORK', 'rails').split(',')
frameworks_versions = frameworks.inject({}) do |frameworks, str|
  framework, *version = str.split('-')
  frameworks.merge(framework => version.join('-'))
end

frameworks_versions.each do |framework, version|
  case version
  when 'master'
    gem framework, github: (GITHUB_REPOS[framework] || "#{framework}/#{framework}")
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

gem 'activerecord-jdbcsqlite3-adapter', platform: :jruby

group :bench do
  gem 'ruby-prof', require: nil, platforms: %i[ruby]
  gem 'stackprof', require: nil, platforms: %i[ruby]
end

gemspec
