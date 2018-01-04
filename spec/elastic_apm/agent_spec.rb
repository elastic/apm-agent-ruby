# frozen_string_literal: true

require 'spec_helper'

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
      it { should delegate :transaction, to: subject.instrumenter }
      it { should delegate :span, to: subject.instrumenter }
      it { should delegate :set_tag, to: subject.instrumenter }
    end

    context 'reporting' do
      class AgentTestError < StandardError; end

      subject { Agent.new Config.new }

      describe '#report' do
        it 'queues a request' do
          exception = AgentTestError.new('Yikes!')

          subject.report(exception)

          expect(subject.queue.length).to be 1

          job = subject.queue.pop
          expect(job).to be_a Worker::Request
        end
      end

      describe '#report_message' do
        it 'queues a request' do
          subject.report_message('Everything went 💥')

          expect(subject.queue.length).to be 1

          job = subject.queue.pop
          expect(job).to be_a Worker::Request
        end
      end
    end

    describe '#enqueue_transactions' do
      subject { Agent.new Config.new }

      it 'enqueues a collection of transactions' do
        transaction = subject.transaction 'T'

        subject.enqueue_transactions([transaction])

        expect(subject.queue.length).to be 1
        job = subject.queue.pop
        expect(job).to be_a Worker::Request
      end
    end
  end
end
