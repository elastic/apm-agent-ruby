# frozen_string_literal: true

module ElasticAPM
  RSpec.describe Worker do
    describe 'a loop' do
      let(:config) { Config.new flush_interval: 0.1 }
      let(:instrumenter) { Instrumenter.new(Agent.new(config)) }
      let(:messages) { Queue.new }
      let(:transactions) { Queue.new }

      around do |example|
        @thread = Thread.new do
          Worker.new(
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

          messages.push(Worker::StopMsg.new)

          sleep 0.2

          expect(@thread).to_not be_alive
        end
      end

      context 'with transactions in the queue', :with_fake_server, :mock_time do
        it 'formats payloads and posts to server' do
          transactions.push build_transaction

          sleep 0.2

          wait_for_requests_to_finish 1

          expect(FakeServer.requests.length).to be 1
        end

        context 'with a small queue size' do
          let(:config) { Config.new flush_interval: 0.1, max_queue_size: 2 }

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
          messages.push Worker::ErrorMsg.new(build_error)

          wait_for_requests_to_finish 1

          expect(FakeServer.requests.length).to be 1
        end
      end

      def build_transaction
        Transaction.new(instrumenter, nil)
      end

      def build_error
        @agent ||= Agent.new(config)
        ErrorBuilder.new(@agent).build_exception(actual_exception)
      end
    end
  end
end
