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

        error, = @intercepted.errors
        expect(error.exception.type).to eq 'ZeroDivisionError'
      end
    end
  end
end
