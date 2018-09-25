# frozen_string_literal: true

module ElasticAPM
  RSpec.describe Agent do
    let(:config) { Config.new }
    subject { Agent.new config }

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
      it 'has an instrumenter' do
        expect(subject.instrumenter).to be_a Instrumenter
      end
    end

    context 'reporting', :mock_intake do
      class AgentTestError < StandardError; end

      describe '#report' do
        it 'queues a request' do
          exception = AgentTestError.new('Yikes!')

          subject.report(exception)
          subject.flush

          expect(@mock_intake.requests.length).to be 1
          expect(@mock_intake.errors.length).to be 1
        end

        it 'ignores filtered exception types' do
          config =
            Config.new(filter_exception_types: %w[ElasticAPM::AgentTestError])
          subject = Agent.new config

          exception = AgentTestError.new("It's ok!")

          subject.report(exception)

          subject.stop
          expect(@mock_intake.requests.length).to be 0
          expect(@mock_intake.errors.length).to be 0
        end
      end

      describe '#report_message' do
        it 'queues a request' do
          subject.report_message('Everything went 💥')

          subject.stop
          expect(@mock_intake.requests.length).to be 1
          expect(@mock_intake.errors.length).to be 1
        end
      end
    end

    describe '#enqueue_transaction', :mock_intake do
      it 'enqueues a collection of transactions' do
        subject.start_transaction
        subject.end_transaction

        subject.stop
        expect(@mock_intake.requests.length).to be 1
        expect(@mock_intake.transactions.length).to be 1
      end
    end

    describe '#add_filter' do
      it 'may add a filter' do
        expect do
          subject.add_filter :key, -> {}
        end.to change(subject.transport.filters, :length).by 1
      end
    end
  end
end
