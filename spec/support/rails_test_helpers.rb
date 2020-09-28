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

SpecLogger = StringIO.new

module RailsTestHelpers
  def self.setup_rails_test_config(config)
    config.secret_key_base = "__secret_key_base"
    config.consider_all_requests_local = false
    config.eager_load = false

    config.elastic_apm.api_request_time = "200ms"
    config.elastic_apm.disable_start_message = true

    if config.respond_to?(:action_mailer)
      config.action_mailer.perform_deliveries = false
    end

    config.logger = Logger.new(SpecLogger)
  end
end

