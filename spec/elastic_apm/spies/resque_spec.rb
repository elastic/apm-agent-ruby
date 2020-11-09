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
require 'resque'

module ElasticAPM
  RSpec.describe 'Spy: Resque', :intercept do
    class TestJob
      @queue = :resque_test

      def self.perform; end
    end

    class ErrorJob
      @queue = :resque_error

      def self.perform
        1 / 0
      end
    end

    around do |example|
      original_value = ::Resque.inline
      ::Resque.inline = true
      example.run
      ::Resque.inline = original_value
    end

    it 'creates a transaction for each job' do
      with_agent do
        ::Resque.enqueue(TestJob)
        ::Resque.enqueue(TestJob)
      end

      expect(@intercepted.transactions.size).to eq 2

      transaction, = @intercepted.transactions
      expect(transaction.name).to eq 'ElasticAPM::TestJob'
      expect(transaction.type).to eq 'Resque'
      expect(transaction.result).to eq 'success'
      expect(transaction.outcome).to eq 'success'
    end

    context 'when there is an error' do
      it 'reports the error' do
        with_agent do
          expect do
            ::Resque.enqueue(ErrorJob)
          end.to raise_error(ZeroDivisionError)
        end

        transaction, = @intercepted.transactions
        expect(transaction.name).to eq 'ElasticAPM::ErrorJob'
        expect(transaction.type).to eq 'Resque'
        expect(transaction.outcome).to eq 'failure'

        error, = @intercepted.errors
        expect(error.exception.type).to eq 'ZeroDivisionError'
      end
    end
  end
end
