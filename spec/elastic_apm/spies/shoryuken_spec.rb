# frozen_string_literal: true

require 'elastic_apm/spies/shoryuken'

begin
  require 'active_job'
rescue LoadError
end

require 'shoryuken'
require 'shoryuken/processor'

module ElasticAPM
  RSpec.describe 'Spy: Shoryuken', :mock_intake do
    class ShoryukenTestingWorker
      include Shoryuken::Worker

      def perform(*_options)
        'ok'
      end
    end

    class ShoryukenHardWorker < ShoryukenTestingWorker
      shoryuken_options queue: 'hard'
    end

    class ShoryukenExplodingWorker < ShoryukenTestingWorker
      shoryuken_options queue: 'exploding'

      def perform(*options)
        super
        1 / 0
      end
    end

    def process_message_double(queue)
      sqs_message = double Shoryuken::Message,
        queue_url: 'https://sqs.ap-northeast-1.amazonaws.com/123456789123/test',
        message_attributes: {},
        message_id: SecureRandom.uuid,
        receipt_handle: SecureRandom.uuid,
        body: 'test'

      Shoryuken::Processor.process(queue, sqs_message)
    end

    before do
      # Mock this function used in the middleware chain
      allow(::ActiveRecord::Base)
        .to receive(:clear_active_connections!)

      Aws.config[:stub_responses] = true
      Aws.config[:region] = 'us-east-1'
      Shoryuken.sqs_client.stub_responses(
        :get_queue_url,
        queue_url: 'https://sqs.ap-northeast-1.amazonaws.com/123456789123/test'
      )

      Shoryuken.add_group('default', 1)
      Shoryuken.add_queue('hard', 1, 'default')
      Shoryuken.add_queue('exploding', 1, 'default')

      # Disable log pollution with Shoryuken
      Shoryuken.logger.level = Logger::UNKNOWN

      Shoryuken.register_worker('hard', ShoryukenHardWorker)
      Shoryuken.register_worker('exploding', ShoryukenExplodingWorker)
    end

    it 'instruments jobs' do
      with_agent do
        process_message_double('hard')
      end

      wait_for transactions: 1

      transaction, = @mock_intake.transactions

      expect(transaction).to_not be_nil
      expect(transaction['name']).to eq 'ElasticAPM::ShoryukenHardWorker'
      expect(transaction['type']).to eq 'shoryuken.job'
      expect(transaction['context']['tags']['shoryuken_queue']).to eq 'hard'
      expect(transaction['result']).to eq 'success'
    end

    it 'reports errors' do
      with_agent do
        expect do
          process_message_double('exploding')
        end.to raise_error(ZeroDivisionError)
      end

      wait_for transactions: 1, errors: 1

      transaction, = @mock_intake.transactions
      error, = @mock_intake.errors

      expect(transaction).to_not be_nil
      expect(transaction['name']).to eq 'ElasticAPM::ShoryukenExplodingWorker'
      expect(transaction['type']).to eq 'shoryuken.job'
      expect(transaction['context']['tags']['shoryuken_queue'])
        .to eq 'exploding'
      expect(transaction['result']).to eq 'error'

      expect(error.dig('exception', 'type')).to eq 'ZeroDivisionError'
    end
  end
end
