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

require "active_support/subscriber"
require 'racecar'

module ElasticAPM
  RSpec.describe 'Spy: Racecar', :intercept do
    class TestConsumer < Racecar::Consumer
      subscribes_to "a_queue"
      def process(message)
        ElasticAPM.current_transaction.inspect
      end
    end

    it 'has a current transaction' do 
      consumer = TestConsumer.new
      current_transaction = consumer.process(nil)
      expect(current_transaction).to be_a(ElasticAPM::Transaction)
    end
  end
end
