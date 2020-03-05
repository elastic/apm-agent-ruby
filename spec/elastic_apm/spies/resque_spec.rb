# frozen_string_literal: true

require 'spec_helper'
require 'resque'

module ElasticAPM
  RSpec.describe 'Spy: Resque' do
    class TestJob
      @queue = :resque_test

      def self.perform; end
    end

    around do |example|
      original_value = ::Resque.inline
      ::Resque.inline = true
      example.run
      ::Resque.inline = original_value
    end

    it 'creates a transaction for each job', :intercept do
      with_agent do
        ::Resque.enqueue(TestJob)
        ::Resque.enqueue(TestJob)
      end

      expect(@intercepted.transactions.size).to eq 2

      transaction, = @intercepted.transactions
      expect(transaction.name).to be(nil)
      expect(transaction.type).to eq 'Resque'
    end
  end
end
