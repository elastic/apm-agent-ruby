# frozen_string_literal: true

module ElasticAPM
  RSpec.describe Agent do
    let(:config) { Config.new }
    subject { Agent.new config }

    describe '#initialize' do
      its(:transport) { should be_a Transport::Base }
      its(:instrumenter) { should be_a Instrumenter }
      its(:stacktrace_builder) { should be_a StacktraceBuilder }
      its(:context_builder) { should be_a ContextBuilder }
      its(:error_builder) { should be_a ErrorBuilder }
    end

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
      let(:instrumenter) { subject.instrumenter }

      it 'should delegate methods to instrumenter' do
        {
          current_transaction: nil,
          current_span: nil,
          start_transaction: [nil, nil, { context: nil, traceparent: nil }],
          end_transaction: [nil],
          start_span: [nil, nil, { backtrace: nil, context: nil }],
          end_span: nil,
          set_tag: [nil, nil],
          set_custom_context: [nil],
          set_user: [nil]
        }.each do |name, args|
          expect(subject).to delegate(name, to: instrumenter, args: args)
        end
      end
    end

    context 'reporting', :intercept do
      describe '#report' do
        it 'queues a request' do
          expect { subject.report(actual_exception) }
            .to change(@intercepted.errors, :length).by 1
        end

        context 'with filtered exception types' do
          class AgentTestError < StandardError; end

          let(:config) do
            Config.new(filter_exception_types: %w[ElasticAPM::AgentTestError])
          end

          it 'ignores exception' do
            exception = AgentTestError.new("It's ok!")

            expect { subject.report(exception) }
              .to change(@intercepted.errors, :length).by 0
          end
        end
      end

      describe '#report_message', :intercept do
        it 'queues a request' do
          expect { subject.report_message('Everything went 💥') }
            .to change(@intercepted.errors, :length).by 1
        end
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
