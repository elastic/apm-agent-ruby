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
  require 'active_job'
rescue LoadError
end

begin
  require 'delayed_job'
  require 'delayed/performable_mailer' # or the Rails spec explodes
rescue LoadError
end

if defined?(Delayed::Backend)
  module ElasticAPM
    RSpec.describe 'Spy: DelayedJob', :intercept do
      class TestJob
        def perform
        end
      end

      class ExplodingJob
        def perform
          1 / 0
        end
      end

      class MockJobBackend
        include Delayed::Backend::Base

        def initialize(job)
          @job = job
        end

        def payload_object
          @job
        end
      end

      before :all do
        Delayed::Worker.backend = MockJobBackend
      end

      it 'instruments class-based job transaction' do
        job = TestJob.new

        with_agent do
          Delayed::Job.new(job).invoke_job
        end

        transaction, = @intercepted.transactions
        expect(transaction.name).to eq 'ElasticAPM::TestJob'
        expect(transaction.type).to eq 'Delayed::Job'
        expect(transaction.result).to eq 'success'
      end

      context 'ActiveJob', if: defined?(ActiveJob) do
        before :all do
          class ::ActiveJobbyJob < ActiveJob::Base
            self.queue_adapter = :delayed_job
            self.logger = nil # stay quiet

            def perform
              'ok'
            end
          end
        end

        after :all do
          Object.send(:remove_const, :ActiveJobbyJob)
        end

        it 'instruments class-based job transaction for active job' do
          job = ActiveJobbyJob.new

          with_agent do
            Delayed::Job.new(job).invoke_job
          end

          transaction, = @intercepted.transactions
          expect(transaction.name).to eq 'ActiveJobbyJob'
          expect(transaction.type).to eq 'Delayed::Job'
          expect(transaction.result).to eq 'success'
        end
      end

      it 'instruments method-based job transaction' do
        job = TestJob.new
        invokable = Delayed::PerformableMethod.new(job, :perform, [])

        with_agent do
          Delayed::Job.new(invokable).invoke_job
        end

        transaction, = @intercepted.transactions
        expect(transaction.name)
          .to eq 'ElasticAPM::TestJob#perform'
        expect(transaction.type).to eq 'Delayed::Job'
        expect(transaction.result).to eq 'success'
        expect(transaction.outcome).to eq 'success'
      end

      it 'reports errors' do
        job = ExplodingJob.new

        expect do
          with_agent do
            Delayed::Job.new(job).invoke_job
          end
        end.to raise_error(ZeroDivisionError)

        transaction, = @intercepted.transactions
        expect(transaction.name).to eq 'ElasticAPM::ExplodingJob'
        expect(transaction.type).to eq 'Delayed::Job'
        expect(transaction.result).to eq 'error'
        expect(transaction.outcome).to eq 'failure'

        error, = @intercepted.errors
        expect(error.exception.type).to eq 'ZeroDivisionError'
      end

      it "runs when the agent doesn't" do
        job = TestJob.new

        expect { Delayed::Job.new(job).invoke_job }
          .to_not raise_error
      end
    end
  end
end
