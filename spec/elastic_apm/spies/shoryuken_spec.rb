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
    unless defined? ::ActiveRecord::Base
      class ::ActiveRecord # rubocop:disable Style/ClassAndModuleChildren
        class Base; end
      end
    end

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

    def call(queue)
      sqs_message = double Shoryuken::Message,
        queue_url: Shoryuken::Client.queues(queue).url,
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

      Shoryuken::Client.sqs.create_queue(queue_name: 'hard')
      Shoryuken::Client.sqs.create_queue(queue_name: 'exploding')

      Shoryuken.add_group('default', 1)
      Shoryuken.add_queue('hard', 1, 'default')
      Shoryuken.add_queue('exploding', 1, 'default')

      ShoryukenHardWorker.get_shoryuken_options['queue'] = 'hard'
      ShoryukenExplodingWorker.get_shoryuken_options['queue'] = 'exploding'

      Shoryuken.register_worker('hard', ShoryukenHardWorker)
      Shoryuken.register_worker('exploding', ShoryukenExplodingWorker)
    end

    it 'instruments jobs' do
      with_agent do
        ShoryukenHardWorker.perform_async('test')
      end

      wait_for transactions: 1

      transaction, = @mock_intake.transactions
      expect(transaction).to_not be_nil
      expect(transaction['name']).to eq 'ElasticAPM::HardWorker'
      expect(transaction['type']).to eq 'shoryuken.job'
    end

    after do
      puts Shoryuken::Client.sqs.api_requests
    end

    it 'reports errors' do
      with_agent do
        expect do
          ShoryukenExplodingWorker.perform_async('test')
        end.to raise_error(ZeroDivisionError)
      end

      wait_for transactions: 1, errors: 1

      transaction, = @mock_intake.transactions
      error, = @mock_intake.errors

      expect(transaction).to_not be_nil
      expect(transaction['name']).to eq 'ElasticAPM::ShoryukenExplodingWorker'
      expect(transaction['type']).to eq 'shoryuken.job'

      expect(error.dig('exception', 'type')).to eq 'ZeroDivisionError'
    end

    context 'ActiveJob', if: defined?(ActiveJob) do
      before :all do
        # rubocop:disable Style/ClassAndModuleChildren
        class ::ActiveJobbyJob < ActiveJob::Base
          queue_as 'active_job'

          # rubocop:enable Style/ClassAndModuleChildren
          self.queue_adapter = :shoryuken
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
          ActiveJobbyJob.perform_later
        end

        wait_for transactions: 1

        transaction, = @mock_intake.transactions
        expect(transaction).to_not be_nil
        expect(transaction['name']).to eq 'ActiveJobbyJob'
      end
    end
  end
end
