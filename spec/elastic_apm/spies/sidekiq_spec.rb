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
    end

    it 'starts when sidekiq processors do' do
      opts = { concurrency: 1, queues: ['default'] }

      manager =
      if Gem::Version.new(Sidekiq::VERSION) >= Gem::Version.new('7.0')
        logger = Logger.new(nil)
        logger.level = ::Logger::UNKNOWN
        config = Sidekiq::Config.new(concurrency: 1)
        config.logger = logger
        Sidekiq::Manager.new(config.default_capsule)
      elsif Gem::Version.new(Sidekiq::VERSION) >= Gem::Version.new('6.5')
        Sidekiq.logger = Logger.new(nil)
        config = Sidekiq
        config[:fetch] = Sidekiq::BasicFetch.new(config)
        Sidekiq::Manager.new(config)
      elsif Gem::Version.new(Sidekiq::VERSION) >= Gem::Version.new('6.1.0')
        Sidekiq::Manager.new(fetch: Sidekiq::BasicFetch.new(opts))
      else
        Sidekiq.logger = Logger.new(nil)
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

      it 'creates a transaction with trace from job' do
        with_agent do
          transaction = ElasticAPM.start_transaction 'Test'
          ElasticAPM.end_transaction

          fake_trace_context = transaction.trace_context

          allow_any_instance_of(ElasticAPM::Spies::SidekiqSpy::Middleware).to receive(:get_trace_context_from).and_return(
            ElasticAPM::TraceContext.parse(
              metadata: {
                'traceparent' => fake_trace_context.traceparent.to_header,
                'tracestate' => fake_trace_context.tracestate.to_header
              }
            )
          )

          Sidekiq::Testing.inline! do
            HardWorker.perform_async
          end
        end

        wait_for transactions: 2

        fake_transaction, worker_transaction = @mock_intake.transactions

        expect(worker_transaction).to_not be_nil
        expect(worker_transaction['trace_id']).to eq(fake_transaction['trace_id'])
        expect(worker_transaction['parent_id']).to eq(fake_transaction['id'])
      end

      context 'ActiveJob', if: defined?(ActiveJob) do
        before :all do
          class ::ActiveJobbyJob < ActiveJob::Base
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

    describe Spies::SidekiqSpy::ClientMiddleware do
      before :all do
        Sidekiq.configure_client do |config|
          config.client_middleware do |chain|
            chain.add Spies::SidekiqSpy::ClientMiddleware
          end
        end
      end

      it 'adds trace context to job' do
        current_transaction =
          with_agent do
            ElasticAPM.with_transaction do |transaction|
              HardWorker.perform_async
              transaction
            end
          end

        current_job = Sidekiq::Queues['default'].first

        trace_context = current_transaction.trace_context

        expect(current_job['elastic_trace_context']['traceparent']).to eq(trace_context.traceparent.to_header)
        expect(current_job['elastic_trace_context']['tracestate']).to eq(trace_context.tracestate.to_header)
      end
    end
  end
end
