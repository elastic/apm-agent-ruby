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

        subject do
          described_class.new(
            config,
            queue,
            serializers: serializers,
            filters: filters,
            conn_adapter: MockConnection
          )
        end

        it 'applies filters, writes resources to the connection' do
          expect(subject.filters).to receive(:apply!)

          queue.push Transaction.new
          Thread.new { subject.work_forever }.join 0.1

          expect(subject.connection.calls.length).to be 1
        end

        it 'can be stopped with a message' do
          expect(subject.connection).to receive(:flush)

          thread = Thread.new { subject.work_forever }
          queue.push Worker::StopMessage.new

          Timeout.timeout(1) { loop while thread.alive? }
        end
      end
    end
  end
end
