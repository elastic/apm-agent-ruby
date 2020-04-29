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

require 'elastic_apm/spies/shoryuken'

begin
  require 'active_job'
rescue LoadError
end

require 'shoryuken'
require 'shoryuken/processor'

module ElasticAPM
  RSpec.describe 'Spy: Shoryuken', :mock_intake do
    class ShoryukenTestingWorker
      include Shoryuken::Worker

      def perform(*_options)
        'ok'
      end
    end

    class ShoryukenHardWorker < ShoryukenTestingWorker
      shoryuken_options queue: 'hard'
    end

    class ShoryukenExplodingWorker < ShoryukenTestingWorker
      shoryuken_options queue: 'exploding'

      def perform(*options)
        super
        1 / 0
      end
    end

    def process_message_double(queue)
      sqs_message = double Shoryuken::Message,
        queue_url: 'https://sqs.ap-northeast-1.amazonaws.com/123456789123/test',
        message_attributes: {},
        message_id: SecureRandom.uuid,
        receipt_handle: SecureRandom.uuid,
        body: 'test'

      Shoryuken::Processor.process(queue, sqs_message)
    end

    before do
      # Mock this function used in the middleware chain
      allow(::ActiveRecord::Base)
        .to receive(:clear_active_connections!)

      Aws.config[:stub_responses] = true
      Aws.config[:region] = 'us-east-1'
      Shoryuken.sqs_client.stub_responses(
        :get_queue_url,
        queue_url: 'https://sqs.ap-northeast-1.amazonaws.com/123456789123/test'
      )

      Shoryuken.add_group('default', 1)
      Shoryuken.add_queue('hard', 1, 'default')
      Shoryuken.add_queue('exploding', 1, 'default')

      # Disable log pollution with Shoryuken
      Shoryuken.logger.level = Logger::UNKNOWN

      Shoryuken.register_worker('hard', ShoryukenHardWorker)
      Shoryuken.register_worker('exploding', ShoryukenExplodingWorker)
    end

    it 'instruments jobs' do
      with_agent do
        process_message_double('hard')
      end

      wait_for transactions: 1

      transaction, = @mock_intake.transactions

      expect(transaction).to_not be_nil
      expect(transaction['name']).to eq 'ElasticAPM::ShoryukenHardWorker'
      expect(transaction['type']).to eq 'shoryuken.job'
      expect(transaction['context']['tags']['shoryuken_queue']).to eq 'hard'
      expect(transaction['result']).to eq 'success'
    end

    it 'reports errors' do
      with_agent do
        expect do
          process_message_double('exploding')
        end.to raise_error(ZeroDivisionError)
      end

      wait_for transactions: 1, errors: 1

      transaction, = @mock_intake.transactions
      error, = @mock_intake.errors

      expect(transaction).to_not be_nil
      expect(transaction['name']).to eq 'ElasticAPM::ShoryukenExplodingWorker'
      expect(transaction['type']).to eq 'shoryuken.job'
      expect(transaction['context']['tags']['shoryuken_queue'])
        .to eq 'exploding'
      expect(transaction['result']).to eq 'error'

      expect(error.dig('exception', 'type')).to eq 'ZeroDivisionError'
    end
  end
end
