# frozen_string_literal: true

require 'elastic_apm/transport/connection'

module ElasticAPM
  module Transport
    RSpec.describe Connection do
      subject { Connection.new Config.new }

      describe '#initialize' do
        it { should_not be_connected }
      end

      describe 'write' do
        it 'opens a connection and writes' do
          stub = build_stub('{"msg": "hey!"}')

          subject.write('{"msg": "hey!"}')
          expect(subject).to be_connected

          subject.close!
          expect(subject).to_not be_connected

          expect(stub).to have_been_requested
        end
      end

      context 'when given max request time' do
        subject { described_class.new(Config.new(api_request_time: 0.1)) }

        it 'closes requests when reached' do
          stub = build_stub('{"msg": "time!"}')

          subject.write('{"msg": "time!"}')

          sleep 0.2
          expect(subject).to_not be_connected

          expect(stub).to have_been_requested
        end

        it "doesn't make a scene if already closed" do
          build_stub('{"msg": "time!"}')

          subject.write('{"msg": "time!"}')
          subject.close!

          expect(subject).to_not be_connected

          sleep 0.2
          expect(subject).to_not be_connected
        end
      end

      def build_stub(body)
        WebMock.stub_request(:post, 'http://localhost:8200/v2/intake').with(
          headers: {
            'Transfer-Encoding' => 'chunked',
            'Content-Type' => 'application/x-ndjson'
          },
          body: /#{body}/
        )
      end
    end
  end
end
