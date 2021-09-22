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
require 'sucker_punch'

module ElasticAPM
  RSpec.describe 'Spy: SuckerPunch', :intercept do
    class TestJob
      include ::SuckerPunch::Job
      def perform; end
    end

    class ErrorJob
      include ::SuckerPunch::Job
      def perform
        1 / 0
      end
    end

    context 'when SuckerPunch::Job.new.perform is called' do
      before do
        with_agent do
          TestJob.new.perform
        end
      end

      it 'does not create a transaction' do
        expect(@intercepted.transactions.size).to eq 0
      end
    end

    context 'when the job is successful' do
      context 'when SuckerPunch::Job.perform_async is called' do
        before do
          with_agent do
            TestJob.perform_async
            sleep(0.5)
          end
        end

        it 'creates a transaction' do
          expect(@intercepted.transactions.size).to eq 1
          transaction, = @intercepted.transactions
          expect(transaction.name).to eq 'ElasticAPM::TestJob'
          expect(transaction.type).to eq 'sucker_punch'
          expect(transaction.result).to eq 'success'
          expect(transaction.outcome).to eq 'success'
        end
      end

      context 'when SuckerPunch::Job.perform_in is called' do
        before do
          with_agent do
            TestJob.perform_in(0.5)
            sleep(1)
          end
        end

        it 'creates a transaction' do
          expect(@intercepted.transactions.size).to eq 1
          transaction, = @intercepted.transactions
          expect(transaction.name).to eq 'ElasticAPM::TestJob'
          expect(transaction.type).to eq 'sucker_punch'
          expect(transaction.result).to eq 'success'
          expect(transaction.outcome).to eq 'success'
        end
      end
    end

    context 'when the job raises an error' do
      around do |ex|
        original_exception_handler = SuckerPunch.exception_handler
        # We set an exception handler that does nothing so we don't see the
        # error reported to STDOUT in the tests
        SuckerPunch.exception_handler = proc { nil }
        ex.run
        SuckerPunch.exception_handler = original_exception_handler
        SuckerPunch::Counter::Failed::COUNTER.clear
      end

      context 'when SuckerPunch::Job.perform_async is called' do
        it 'sets transaction result to success, SuckerPunch handles error' do
          with_agent do
            ErrorJob.perform_async
            sleep(0.5)
          end

          expect(
            SuckerPunch::Counter::Failed::COUNTER['ElasticAPM::ErrorJob'].value
          ).to eq 1

          transaction, = @intercepted.transactions
          expect(transaction.name).to eq 'ElasticAPM::ErrorJob'
          expect(transaction.type).to eq 'sucker_punch'
          expect(transaction.result).to eq 'success'
          expect(transaction.outcome).to eq 'success'
          expect(@intercepted.errors.size).to eq 0
        end
      end

      context 'when SuckerPunch::Job.perform_in is called' do
        it 'sets transaction result to success, SuckerPunch handles error' do
          with_agent do
            ErrorJob.perform_in(0.5)
            sleep(1)
          end

          expect(
            SuckerPunch::Counter::Failed::COUNTER['ElasticAPM::ErrorJob'].value
          ).to eq 1

          transaction, = @intercepted.transactions
          expect(transaction.name).to eq 'ElasticAPM::ErrorJob'
          expect(transaction.type).to eq 'sucker_punch'
          expect(transaction.result).to eq 'success'
          expect(transaction.outcome).to eq 'success'
          expect(@intercepted.errors.size).to eq 0
        end
      end
    end
  end
end
