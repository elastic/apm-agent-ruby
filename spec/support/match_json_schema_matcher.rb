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

require 'spec_helper'
require 'json-schema'

base = 'https://raw.githubusercontent.com/elastic/apm-server/master/docs/spec'

SCHEMA_URLS = {
  metadatas: "#{base}/metadata.json",
  transactions: "#{base}/transactions/transaction.json",
  spans: "#{base}/spans/span.json",
  errors: "#{base}/errors/error.json",
  metricset: "#{base}/metricsets/metricset.json"
}.freeze

RSpec::Matchers.define :match_json_schema do |schema|
  match do |json|
    begin
      WebMock.disable!
      url = SCHEMA_URLS.fetch(schema)
      JSON::Validator.validate!(url, json)
    rescue JSON::ParserError, JSON::Schema::ValidationError # jruby sometimes weirds out
      puts json.inspect
      raise
    ensure
      WebMock.enable!
    end
  end
end
