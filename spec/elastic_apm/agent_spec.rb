# Licensed to Elasticsearch B.V. under one or more contributor
# license agreements. See the NOTICE file distributed with
# this work for additional information regarding copyright
# ownership. Elasticsearch B.V. licenses this file to you under
# the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

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
      its(:metrics) { should be_a Metrics::Registry }
    end

    context 'life cycle', :mock_intake do
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

        context 'when enabled: false' do
          let(:config) { Config.new(enabled: false) }

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
          end_transaction: [nil],
          start_span: [
            nil,
            nil,
            {
              subtype: nil,
              action: nil,
              backtrace: nil,
              context: nil,
              trace_context: nil,
              parent: nil,
              sync: nil
            }
          ],
          end_span: nil,
          set_label: [nil, nil],
          set_custom_context: [nil],
          set_user: [nil]
        }.each do |name, args|
          expect(subject).to delegate(name, to: instrumenter, args: args)
        end
      end

      it 'passes the config when starting a transaction' do
        expect(instrumenter).to receive(:start_transaction).with(
          nil, nil, context: nil, trace_context: nil, config: subject.config
        )
        subject.start_transaction
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

    context 'metrics', :mock_intake do
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

    context 'when the process is forked' do
      around do |ex|
        subject.start
        ex.run
        subject.stop
      end

      it 'calls handle_forking! on all associated objects' do
        allow(Process).to receive(:pid).and_return(1)

        expect(subject.central_config).to receive(:handle_forking!)
        expect(subject.transport).to receive(:handle_forking!)
        expect(subject.instrumenter).to receive(:handle_forking!)
        expect(subject.metrics).to receive(:handle_forking!)

        subject.report_message('Everything went boom')
      end
    end
  end
end
