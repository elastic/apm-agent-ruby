require 'spec_helper'

module ElasticAPM
  RSpec.describe TimedWorker do
    describe 'a loop' do
      let(:messages) { Queue.new }
      let(:transactions) { Queue.new }
      let(:config) { Config.new }

      around do |example|
        @thread = Thread.new do
          TimedWorker.new(
            config,
            messages,
            transactions,
            Http.new(config)
          ).run_forever
        end

        begin
          example.run
        ensure
          Thread.kill(@thread)
          @thread.join 0.1
        end
      end

      context 'with a stop message', :with_fake_server do
        it 'exits thread' do
          expect(@thread).to be_alive

          messages.push(TimedWorker::StopMsg.new)

          sleep 0.2

          expect(@thread).to_not be_alive
        end
      end

      context 'with transactions in the queue', :with_fake_server, :mock_time do
        it 'formats payloads and posts to server' do
          transactions.push build_transaction

          sleep 0.1

          travel 10_000

          wait_for_requests_to_finish 1

          expect(FakeServer.requests.length).to be 1
        end

        context 'with a small queue size' do
          let(:config) { Config.new max_queue_size: 2 }

          it 'breaks the loop if reaching max queue size' do
            transactions.push build_transaction
            transactions.push build_transaction

            wait_for_requests_to_finish 1

            expect(FakeServer.requests.length).to be 1
          end
        end
      end

      context 'with an error message', :with_fake_server do
        it 'posts to server' do
          messages.push TimedWorker::ErrorMsg.new(build_error)

          wait_for_requests_to_finish 1

          expect(FakeServer.requests.length).to be 1
        end
      end

      def build_transaction
        Transaction.new(nil, nil)
      end

      def build_error
        ErrorBuilder.new(Config.new).build_exception(actual_exception)
      end
    end
  end
end
