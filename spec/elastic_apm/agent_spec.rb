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
      its(:metrics) { should be_a Metrics::Collector }
    end

    context 'life cycle' do
      describe '.start' do
        it 'starts an instance and only one' do
          first_instance = Agent.start Config.new
          expect(Agent.instance).to_not be_nil
          expect(Agent.start(Config.new)).to be first_instance

          Agent.stop # clean up
        end

        it 'starts subservices' do
          expect(subject.central_config).to receive(:start) { nil }
          expect(subject.transport).to receive(:start) { nil }
          expect(subject.instrumenter).to receive(:start) { nil }
          expect(subject.metrics).to receive(:start) { nil }
          subject.start
          subject.stop
        end

        context 'when active: false' do
          let(:config) { Config.new(active: false) }

          it "doesn't start" do
            Agent.start(config)
            expect(Agent.instance).to be nil
          end
        end
      end

      describe '.stop' do
        it 'kill the running instance' do
          Agent.start Config.new
          Agent.stop

          expect(Agent.instance).to be_nil
        end

        it 'stops subservices' do
          expect(subject.central_config).to receive(:stop)
          expect(subject.transport).to receive(:stop)
          expect(subject.instrumenter).to receive(:stop)
          expect(subject.metrics).to receive(:stop)
          subject.stop
        end
      end
    end

    context 'instrumenting' do
      let(:instrumenter) { subject.instrumenter }

      it 'should delegate methods to instrumenter' do
        {
          current_transaction: nil,
          current_span: nil,
          start_transaction: [nil, nil, { context: nil, trace_context: nil }],
          end_transaction: [nil],
          start_span: [
            nil,
            nil,
            { backtrace: nil, context: nil, trace_context: nil }
          ],
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

        it 'returns error object' do
          result = subject.report(actual_exception)
          expect(result).to be_a String
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

        it 'returns error object' do
          result = subject.report_message(actual_exception)
          expect(result).to be_a String
        end
      end
    end

    context 'metrics', :intercept do
      it 'starts' do
        subject.start
        expect(subject.metrics).to be_running
        subject.stop
      end

      context 'when interval is zero' do
        let(:config) { Config.new metrics_interval: 0 }

        it "doesn't start" do
          subject.start
          expect(subject.metrics).to_not be_running
          subject.stop
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
