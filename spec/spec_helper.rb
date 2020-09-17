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

  SimpleCov.coverage_dir("coverage/matrix_results/" + ENV["TEST_MATRIX"])
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

# SpecLogger = StringIO.new

RSpec.configure do |config|
  config.order = :random

  config.include(ExceptionHelpers)
  config.include(WithAgent)
  config.include(PlatformHelpers)
  config.include(RailsTestHelpers) if defined?(Rails)

  if config.files_to_run.one?
    config.default_formatter = "documentation"
  end

  unless ENV["INCLUDE_SCHEMA_SPECS"]
    config.filter_run_excluding(type: "json_schema")
  end

  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!

  config.backtrace_inclusion_patterns = [/elastic_apm/]

  config.before(:each) do |example|
    if ElasticAPM.running? && !example.metadata[:allow_running_agent]
      raise "Previous example left an agent running"
    end
  end

  config.after(:each) do |example|
    if ElasticAPM.running? && !example.metadata[:allow_running_agent]
      raise "This example left an agent running"
    end
  end

  config.after(:each, spec_logger: true) do |example|
    SpecLogger.rewind
    next unless example.exception

    puts("Example failed, dumping log:")
    puts(SpecLogger.read)
  end
end

RSpec.shared_context("stubbed_central_config") do
  before(:all) do
    WebMock.stub_request(
      :get,
      %r{^http://localhost:8200/config/v1/agents/?$}    ).to_return(body: "{}")
  end

  after(:all) do
    WebMock.reset!
  end
end
