# frozen_string_literal: true

module ElasticAPM
  RSpec.describe Agent do
    context 'life cycle' do
      describe '.start' do
        it 'starts an instance and only one' do
          first_instance = Agent.start Config.new
          expect(Agent.instance).to_not be_nil
          expect(Agent.start(Config.new)).to be first_instance

          Agent.stop # clean up
        end

        it 'prints a disabled warning when env not included' do
          expect($stdout).to receive(:puts)
          Agent.start Config.new(environment: 'other')
          Agent.stop

          expect($stdout).to_not receive(:puts)
          Agent.start Config.new(disable_environment_warning: true)
          Agent.stop
        end
      end

      describe '.stop' do
        it 'kill the running instance' do
          Agent.start Config.new
          Agent.stop

          expect(Agent.instance).to be_nil
        end
      end
    end

    context 'instrumenting' do
      subject { Agent.new Config.new }
      it { should delegate :current_transaction, to: subject.instrumenter }
      it do
        should delegate :transaction,
          to: subject.instrumenter,
          args: ['name', 'type', { context: nil, sampled: true }]
      end
      it do
        should delegate :span,
          to: subject.instrumenter,
          args: ['name', 'type', { backtrace: nil, context: nil }]
      end
      it do
        should delegate :set_tag,
          to: subject.instrumenter, args: [:key, 'value']
      end
      it do
        should delegate :set_custom_context,
          to: subject.instrumenter, args: [{}]
      end
      it do
        should delegate :set_user,
          to: subject.instrumenter, args: ['user']
      end
    end

    context 'reporting', :with_fake_server do
      class AgentTestError < StandardError; end

      subject { ElasticAPM.start }
      after { ElasticAPM.stop }

      describe '#report' do
        it 'queues a request' do
          exception = AgentTestError.new('Yikes!')

          subject.report(exception)
          wait_for_requests_to_finish 1

          expect(FakeServer.requests.length).to be 1
        end

        it 'ignores filtered exception types' do
          config =
            Config.new(filter_exception_types: %w[ElasticAPM::AgentTestError])
          agent = Agent.new config
          exception = AgentTestError.new("It's ok!")

          agent.report(exception)

          expect(FakeServer.requests.length).to be 0
        end
      end

      describe '#report_message' do
        it 'queues a request' do
          subject.report_message('Everything went 💥')
          wait_for_requests_to_finish 1

          expect(FakeServer.requests.length).to be 1
        end
      end
    end

    describe '#enqueue_transaction', :with_fake_server do
      subject { Agent.new Config.new(flush_interval: nil) }

      it 'enqueues a collection of transactions' do
        transaction = subject.transaction

        subject.enqueue_transaction(transaction)
        wait_for_requests_to_finish 1

        expect(FakeServer.requests.length).to be 1
      end

      after { subject.stop }
    end

    describe '#add_filter' do
      subject { Agent.new Config.new }

      it 'may add a filter' do
        expect do
          subject.add_filter :key, -> {}
        end.to change(subject.http.filters, :length).by 1
      end
    end
  end
end
