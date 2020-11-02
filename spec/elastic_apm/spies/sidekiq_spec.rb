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

require 'fakeredis/rspec'
require 'sidekiq'
require 'sidekiq/manager'
require 'sidekiq/testing'

require 'elastic_apm/spies/sidekiq'

begin
  require 'active_job'
rescue LoadError
end

module ElasticAPM
  RSpec.describe 'Spy: Sidekiq', :mock_intake do
    class TestingWorker
      include Sidekiq::Worker

      def perform
        'ok'
      end
    end

    class HardWorker < TestingWorker; end
    class ExplodingWorker < TestingWorker
      def perform
        super
        1 / 0
      end
    end

    before :all do
      Sidekiq::Testing.server_middleware do |chain|
        chain.add Spies::SidekiqSpy::Middleware
      end

      Sidekiq.logger = Logger.new(nil) # sssshh, we're testing
    end

    it 'starts when sidekiq processors do' do
      opts = { concurrency: 1, queues: ['default'] }

      manager =
        if Gem::Version.new(Sidekiq::VERSION) >= Gem::Version.new('6.1.0')
          Sidekiq::Manager.new(fetch: Sidekiq::BasicFetch.new(opts))
        else
          Sidekiq::Manager.new(opts)
        end

      manager.start

      expect(ElasticAPM.agent).to_not be_nil

      manager.stop(::Process.clock_gettime(::Process::CLOCK_MONOTONIC))

      expect(ElasticAPM.agent).to be_nil
      expect(manager).to be_stopped
    end

    context 'with an agent' do
      it 'instruments jobs' do
        with_agent do
          Sidekiq::Testing.inline! do
            HardWorker.perform_async
          end
        end

        wait_for transactions: 1

        transaction, = @mock_intake.transactions
        expect(transaction).to_not be_nil
        expect(transaction['name']).to eq 'ElasticAPM::HardWorker'
        expect(transaction['type']).to eq 'Sidekiq'
        expect(transaction['outcome']).to eq 'success'
      end

      it 'reports errors' do
        with_agent do
          Sidekiq::Testing.inline! do
            expect do
              ExplodingWorker.perform_async
            end.to raise_error(ZeroDivisionError)
          end
        end

        wait_for transactions: 1, errors: 1

        transaction, = @mock_intake.transactions
        error, = @mock_intake.errors

        expect(transaction).to_not be_nil
        expect(transaction['name']).to eq 'ElasticAPM::ExplodingWorker'
        expect(transaction['type']).to eq 'Sidekiq'
        expect(transaction['outcome']).to eq 'failure'

        expect(error.dig('exception', 'type')).to eq 'ZeroDivisionError'
      end

      context 'ActiveJob', if: defined?(ActiveJob) do
        before :all do
          # rubocop:disable Style/ClassAndModuleChildren
          class ::ActiveJobbyJob < ActiveJob::Base
            # rubocop:enable Style/ClassAndModuleChildren
            self.queue_adapter = :sidekiq
            self.logger = nil # stay quiet

            def perform
              'ok'
            end
          end
        end

        after :all do
          Object.send(:remove_const, :ActiveJobbyJob)
        end

        it 'knows the name of ActiveJob jobs', if: defined?(ActiveJob) do
          with_agent do
            Sidekiq::Testing.inline! do
              ActiveJobbyJob.perform_later
            end
          end

          wait_for transactions: 1

          transaction, = @mock_intake.transactions
          expect(transaction).to_not be_nil
          expect(transaction['name']).to eq 'ActiveJobbyJob'
        end
      end
    end
  end
end
