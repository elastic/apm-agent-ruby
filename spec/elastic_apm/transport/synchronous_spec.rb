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

module ElasticAPM
  module Transport
    RSpec.describe Synchronous, :mock_intake do
      let(:config) { Config.new }

      subject { described_class.new config }

      describe '#initialize' do
        its(:queue) { should be_a Queue }
      end

      describe '#stop' do
        it 'flushes all events', :mock_intake do
          subject.start

          subject.submit Transaction.new config: config
          subject.submit Transaction.new config: config
          subject.submit Transaction.new config: config

          expect(@mock_intake.transactions.size).to eq 0
          subject.stop

          wait_for transactions: 3
        end
      end

      describe '#submit' do
        it 'adds stuff to the queue' do
          subject.submit Transaction.new config: config
          expect(subject.queue.length).to be 1
        end

        context 'when queue is full' do
          let(:config) { Config.new(api_buffer_size: 5) }

          it 'skips if queue is full' do
            5.times { subject.submit Transaction.new config: config }

            expect(config.logger).to receive(:warn)

            expect { subject.submit Transaction.new config: config }
                .to_not raise_error

            expect(subject.queue.length).to be 5
          end
        end
      end

      describe 'stop and start again' do
        before do
          subject.start
          subject.stop
          subject.start
        end
        after { subject.stop }

        it 'does something' do
          skip 'implementation'
        end
      end

      describe '#handle_forking!' do
        it 'does something' do
          skip 'implementation'
          subject.handle_forking!


          subject.stop
        end
      end
    end
  end
end
