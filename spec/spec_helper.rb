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

if ENV["TEST_MATRIX"]
  require "simplecov"

  SimpleCov.coverage_dir("coverage/matrix_results/#{ENV['TEST_MATRIX']}")
  SimpleCov.start { add_filter("/spec/") }
end

ENV["RAILS_ENV"] = ENV["RACK_ENV"] = "test"

require "bundler/setup"

Bundler.require :default, "test"

Dir["spec/support/*.rb"].each do |file|
  require "./#{file}"
end

require "webmock/rspec"
require "elastic-apm"

RSpec.configure do |config|
  config.order = :random

  config.include(ExceptionHelpers)
  config.include(WithAgent)
  config.include(PlatformHelpers)

  config.backtrace_inclusion_patterns = [/elastic_apm/]
  config.default_formatter = "documentation" if config.files_to_run.one?
  config.disable_monkey_patching!
  config.example_status_persistence_file_path = ".rspec_status"
  config.filter_run_excluding(type: "json_schema") unless ENV["INCLUDE_SCHEMA_SPECS"]
end

module ElasticAPM
  class Config
    option :central_config, type: :bool, default: false
    option :cloud_provider, type: :string, default: 'none'
  end
end
