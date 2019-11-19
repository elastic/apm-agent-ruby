# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  module Transport
    RSpec.describe Worker do
      let(:config) { Config.new }
      let(:queue) { Queue.new }
      let(:serializers) { Serializers.new config }
      let(:filters) { Filters.new config }
      subject do
        described_class.new(
          config,
          queue,
          serializers: serializers,
          filters: filters
        )
      end

      describe '#initialize' do
        its(:filters) { should be_a Filters::Container }
        its(:serializers) { should be_a Serializers::Container }
        its(:connection) { should be_a Connection }
      end

      describe '#ensure_running!' do
        class MockConnection
          def initialize(*_args)
            @calls = []
          end

          attr_reader :calls

          def write(*args)
            calls << args
          end

          def flush; end
        end

        subject do
          described_class.new(
            config,
            queue,
            serializers: serializers,
            filters: filters,
            conn_adapter: MockConnection
          )
        end

        context 'when there are filters' do
          before do
            expect(subject.filters).to receive(:apply!)
            queue.push Transaction.new config: config
            subject.ensure_running!
            subject.stop!(0.1)
          end

          it 'applies filters, writes resources to the connection' do
            expect(subject.connection.calls.length).to be 1
          end
        end

        context 'when a stop message is enqueued' do
          it 'the work is stopped' do
            expect(subject.connection).to receive(:flush)
            subject.ensure_running!
            queue.push Worker::StopMessage.new
            subject.stop!(1)
          end
        end

        context 'when a filter wants to skip the event' do
          before do
            filters.add(:always_nil, ->(_payload) { nil })
            queue.push Transaction.new config: config
            subject.ensure_running!
            subject.stop!(0.1)
          end

          it 'applies filters, writes resources to the connection' do
            expect(subject.connection.calls.length).to be 0
          end
        end
      end

      context 'when the worker is stopped and started again' do
        subject do
          described_class.new(
              config,
              queue,
              serializers: serializers,
              filters: filters,
              conn_adapter: MockConnection
          )
        end

        before do
          subject.ensure_running!
          queue.push Transaction.new config: config
          subject.stop!(0.1)
          subject.ensure_running!
          queue.push Transaction.new config: config
          subject.stop!(0.1)
        end

        it 'stops and starts the thread' do
          expect(subject.connection.calls.length).to be 2
        end
      end

      describe '#kill' do
        subject do
          described_class.new(
              config,
              queue,
              serializers: serializers,
              filters: filters,
              conn_adapter: MockConnection
          )
        end

        before do
          subject.ensure_running!
          queue.push Transaction.new config: config
          sleep(0.1)
          subject.kill!
        end

        it 'kills the thread' do
          expect(subject.connection.calls.length).to be 1
          expect(subject.alive?).to be false
        end
      end

      describe '#stop' do
        subject do
          described_class.new(
              config,
              queue,
              serializers: serializers,
              filters: filters,
              conn_adapter: MockConnection
          )
        end

        before do
          subject.ensure_running!
          queue.push Transaction.new config: config
          subject.stop!(0.1)
        end

        it 'stops the thread' do
          expect(subject.connection.calls.length).to be 1
          expect(subject.alive?).to be false
        end
      end

      describe '#process' do
        context 'when an exception is thrown' do
          let(:event) do
            Transaction.new(
              "What's in a name ⁉️",
              (+'👏').force_encoding('ascii-8bit'),
              config: config
            )
          end

          before do
            expect(config.logger).to receive(:error).twice.and_call_original
          end

          it 'rescues the exception' do
            expect do
              subject.process event
            end.to_not raise_error
          end
        end
      end
    end
  end
end
