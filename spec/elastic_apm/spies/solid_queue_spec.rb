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

# Solid Queue ships +SolidQueue::ClaimedExecution+ as an ActiveRecord model
# under +app/models+, loaded via the engine through Zeitwerk. To avoid
# requiring a full Rails boot here, the spec defines a stand-in constant with
# the same shape and lets the spy hook it.
module SolidQueue
  class ClaimedExecution
    attr_reader :job

    def initialize(job)
      @job = job
    end

    # Real solid_queue runs +ActiveJob::Base.execute+ here. For the spec we
    # just dispatch to the test job stub so that +super+ inside the spy's
    # +Ext+ module is exercised end-to-end.
    def perform
      job.run if job.respond_to?(:run)
    end
  end
end

require 'elastic_apm/spies/solid_queue'

module ElasticAPM
  RSpec.describe 'Spy: SolidQueue', :intercept do
    class TestSolidQueueJob
      attr_reader :queue_name

      def initialize(queue_name: 'default')
        @queue_name = queue_name
      end

      def class_name
        self.class.name
      end

      def run
      end
    end

    class ExplodingSolidQueueJob < TestSolidQueueJob
      def run
        raise ZeroDivisionError, 'boom'
      end
    end

    it 'instruments successful job perform' do
      with_agent do
        ::SolidQueue::ClaimedExecution.new(TestSolidQueueJob.new).perform
      end

      transaction, = @intercepted.transactions
      expect(transaction).to_not be_nil
      expect(transaction.name).to eq 'ElasticAPM::TestSolidQueueJob'
      expect(transaction.type).to eq 'SolidQueue'
      expect(transaction.result).to eq 'success'
      expect(transaction.outcome).to eq 'success'

      labels = transaction.context.labels
      expect(labels[:queue]).to eq 'default'
    end

    it 'reports errors and marks transaction as failure' do
      expect do
        with_agent do
          ::SolidQueue::ClaimedExecution.new(ExplodingSolidQueueJob.new).perform
        end
      end.to raise_error(ZeroDivisionError)

      transaction, = @intercepted.transactions
      expect(transaction.name).to eq 'ElasticAPM::ExplodingSolidQueueJob'
      expect(transaction.type).to eq 'SolidQueue'
      expect(transaction.outcome).to eq 'failure'
      expect(transaction.result).to eq 'error'

      error, = @intercepted.errors
      expect(error.exception.type).to eq 'ZeroDivisionError'
    end

    it 'captures the queue label from the job' do
      with_agent do
        job = TestSolidQueueJob.new(queue_name: 'critical')
        ::SolidQueue::ClaimedExecution.new(job).perform
      end

      transaction, = @intercepted.transactions
      expect(transaction.context.labels[:queue]).to eq 'critical'
    end

    it 'creates a transaction for each perform call' do
      with_agent do
        ::SolidQueue::ClaimedExecution.new(TestSolidQueueJob.new).perform
        ::SolidQueue::ClaimedExecution.new(TestSolidQueueJob.new).perform
      end

      expect(@intercepted.transactions.size).to eq 2
    end

    it 'prepends the Ext module onto SolidQueue::ClaimedExecution' do
      expect(::SolidQueue::ClaimedExecution.ancestors)
        .to include(Spies::SolidQueueSpy::Ext)
    end

    it "runs when the agent doesn't" do
      expect do
        ::SolidQueue::ClaimedExecution.new(TestSolidQueueJob.new).perform
      end.to_not raise_error
    end
  end
end
