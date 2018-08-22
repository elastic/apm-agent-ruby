# frozen_string_literal: true

require 'elastic_apm/transport/connection'

module ElasticAPM
  RSpec.describe Connection do
    describe '#initialize' do
      it { should_not be_connected }
    end

    describe 'write' do
      it 'opens a connection and writes' do
        stub = WebMock.stub_request(
          :post,
          'http://localhost:4321/v2/intake'
        ).with(
          headers: {
            'Transfer-Encoding' => 'chunked',
            'Content-Type' => 'application/x-ndjson'
          },
          body: /{"msg": "hey!"}/
        )

        subject.write('{"msg": "hey!"}')
        expect(subject).to be_connected

        subject.close!
        expect(subject).to_not be_connected

        expect(stub).to have_been_requested
      end
    end
  end
end
