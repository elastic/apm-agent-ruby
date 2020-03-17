# frozen_string_literal: true

require 'spec_helper'

require 'sneakers'
require 'elastic_apm/spies/sneakers'

module ElasticAPM
  RSpec.describe 'Spy: Sneakers', :intercept do
    class MockQueue
      def name
        'q1'
      end
    end

    class MockConsumer
      def queue
        MockQueue.new
      end
    end

    class MockDeliveryInfo
      def routing_key
        'r1234'
      end

      def consumer
        MockConsumer.new
      end
    end

    class TestWorker
      include Sneakers::Worker

      from_queue 'q1', ack: false

      def work(message)
      end
    end

    class TestErrorWorker
      include Sneakers::Worker

      from_queue 'q1', ack: false

      def work(_message)
        1 / 0
      end
    end

    before :all do
      Sneakers.configure
      Sneakers.logger = Logger.new(nil) # silence
    end

    it 'instruments job transaction' do
      with_agent do
        worker = TestWorker.new
        worker.process_work(MockDeliveryInfo.new, nil, nil, nil)
      end

      transaction, = @intercepted.transactions

      expect(transaction.name).to eq 'q1'
      expect(transaction.type).to eq 'Sneakers'
      expect(transaction.result).to eq :success

      label, = transaction.context.labels
      expect(label[:routing_key]).to eq 'r1234'
    end

    it 'reports errors' do
      with_agent do
        worker = TestErrorWorker.new
        worker.process_work(MockDeliveryInfo.new, nil, nil, nil)
      end

      transaction, = @intercepted.transactions

      expect(transaction.name).to eq 'q1'

      label, = transaction.context.labels
      expect(label[:routing_key]).to eq 'r1234'
      expect(transaction.type).to eq 'Sneakers'
      expect(transaction.result).to eq :error

      error, = @intercepted.errors
      expect(error.exception.type).to eq 'ZeroDivisionError'
    end
  end
end
