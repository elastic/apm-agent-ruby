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

      describe '#work_forever' do
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

        around do |example|
          original_adapter = described_class.adapter
          described_class.adapter = MockConnection
          example.run
          described_class.adapter = original_adapter
        end

        subject do
          described_class.new(
            config,
            queue,
            serializers: serializers,
            filters: filters
          )
        end

        it 'applies filters, writes resources to the connection' do
          expect(subject.filters).to receive(:apply!)

          queue.push Transaction.new config: config
          Thread.new { subject.work_forever }.join 0.2

          expect(subject.connection.calls.length).to be 1
        end

        it 'can be stopped with a message' do
          expect(subject.connection).to receive(:flush)

          thread = Thread.new { subject.work_forever }
          queue.push Worker::StopMessage.new

          thread.join 1
        end

        context 'when a filter wants to skip the event' do
          before do
            filters.add(:always_nil, ->(_payload) { nil })
          end

          it 'applies filters, writes resources to the connection' do
            queue.push Transaction.new config: config

            Thread.new { subject.work_forever }.join 0.2

            expect(subject.connection.calls.length).to be 0
          end
        end
      end

      describe '#process' do
        it 'rescues exceptions', :mock_intake do
          with_agent(config: config) do
            event = Transaction.new(
              "What's in a name ⁉️",
              (+'👏').force_encoding('ascii-8bit'),
              config: config
            )

            expect(ElasticAPM.config.logger).to receive(:error).twice.and_call_original

            expect do
              subject.process event
            end.to_not raise_error
          end
        end
      end
    end
  end
end
