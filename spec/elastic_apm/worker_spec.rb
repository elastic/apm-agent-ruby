# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  RSpec.describe Worker do
    class FakeHttp
      def initialize(_config)
        @@reqs ||= [] # rubocop:disable Style/ClassVars
      end

      def post(path, data)
        @@reqs.push([path, data])
      end

      def self.reqs
        @@reqs
      end
    end

    describe 'a loop' do
      let(:queue) { Queue.new }
      subject { Worker.new(Config.new, queue, http: FakeHttp) }

      context 'with an empty queue' do
        it 'does not make any requests' do
          Thread.new { subject.run_forever }.join 0.01
          expect(FakeHttp.reqs).to be_empty
        end
      end

      context 'with a stop message' do
        it 'exits its thread' do
          thread = Thread.new { subject.run_forever }

          queue.push Worker::StopMessage.new

          thread.join 0.01

          expect(thread).to_not be_alive
          expect(queue).to be_empty
        end
      end

      context 'with a request in the queue' do
        it 'pops requests and sends them to the adapter' do
          queue.push Worker::Request.new('/', { id: 1 }.to_json)
          queue.push Worker::Request.new('/', { id: 2 }.to_json)

          Thread.new { subject.run_forever }.join 0.01

          expect(FakeHttp.reqs).to eq [['/', '{"id":1}'], ['/', '{"id":2}']]
        end
      end
    end
  end
end
