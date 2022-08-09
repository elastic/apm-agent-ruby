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

begin
  require 'active_support/notifications'
  require "active_support/subscriber"
  require 'racecar'

  module ElasticAPM
    RSpec.describe 'Spy: Racecar', :intercept do
      it 'captures the instrumentation' do
        with_agent do
          ActiveSupport::Notifications.instrument('start_process_message.racecar')
          ActiveSupport::Notifications.instrument('process_message.racecar') do
            # this is the body of the racecar consumer #process method
          end
          first_transaction = @intercepted.transactions.first
          expect(first_transaction).not_to be_nil
          expect(first_transaction.name).to eq('process_message')
          expect(first_transaction.type).to eq('kafka')
        end
      end
    end
  end

rescue LoadError # in case we don't have ActiveSupport
end