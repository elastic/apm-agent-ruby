# Licensed to Elasticsearch B.V. under one or more contributor
# license agreements. See the NOTICE file distributed with
# this work for additional information regarding copyright
# ownership. Elasticsearch B.V. licenses this file to you under
# the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

# frozen_string_literal: true

source 'https://rubygems.org'

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

# Tools
gem 'cucumber', require: false
gem 'rack-test'
gem 'rspec', '~> 3'
gem 'rspec-its'
gem 'timecop'
gem 'webmock'

# Integrations
gem 'aws-sdk-dynamodb', require: nil
gem 'aws-sdk-s3', require: nil
gem 'aws-sdk-sqs', require: nil
gem 'aws-sdk-sns', require: nil
gem 'elasticsearch', require: nil
gem 'fakeredis', require: nil
gem 'faraday', require: nil
gem 'graphql', require: nil
if !defined?(JRUBY_VERSION) && RUBY_VERSION < '2.5'
  gem 'google-protobuf', '< 3.12'
end
gem 'grpc' if !defined?(JRUBY_VERSION) && RUBY_VERSION < '3.0'
gem 'json'
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
gem 'sucker_punch', '~> 2.0', require: nil
gem 'yard', require: nil
gem 'yarjuf'

# See issue #6547 in the JRuby repo. When that bug is fixed,
# we can use the latest version of the i18n gem.
gem 'i18n', '< 1.8.8'

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
  when 'master' # sinatra, grape
    gem framework, github: GITHUB_REPOS.fetch(framework)
  when 'main' # rails
    gem framework, github: GITHUB_REPOS.fetch(framework), branch: 'main'
  when /.+/
    gem framework, "~> #{version}.0"
  else
    gem framework
  end
end

if frameworks_versions.key?('rails')
  unless frameworks_versions['rails'] =~ /^(main|6)/
    gem 'delayed_job', require: nil
  end
end

if RUBY_PLATFORM == 'java'
  case rails = frameworks_versions['rails']
  when 'main'
    gem 'activerecord-jdbcsqlite3-adapter', git: 'https://github.com/jruby/activerecord-jdbc-adapter', glob: 'activerecord-jdbcsqlite3-adapter/*.gemspec'
  when ''
    gem 'activerecord-jdbcsqlite3-adapter', "~> 61.0"
  when nil
    gem 'jdbc-sqlite3'
  else
    gem 'activerecord-jdbcsqlite3-adapter', "~> #{rails.tr('.', '')}.0"
  end
elsif frameworks_versions['rails'] =~ /^(4|5)/
  gem 'sqlite3', '~> 1.3.6'
else
  gem 'sqlite3'
end

group :bench do
  gem 'ruby-prof', require: nil, platforms: %i[ruby]
  gem 'stackprof', require: nil, platforms: %i[ruby]
end

gemspec
