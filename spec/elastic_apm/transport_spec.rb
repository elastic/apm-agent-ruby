# frozen_string_literal: true

require 'spec_helper'

Thread.abort_on_exception = true

module ElasticAPM
  class Connection
    HEADERS = {
      'Content-Type' => 'application/x-ndjson',
      'Transfer-Encoding' => 'chunked'
    }.freeze

    def initialize
      @mutex = Mutex.new
      @client = HTTP.headers(HEADERS)
      @connected = false
    end

    attr_reader :client

    def close!
      @wr.close
      @conn_thread.join
    end

    def write(str)
      connect! unless connected?

      @wr.puts(str)
    end

    def connected?
      @mutex.synchronize { @connected }
    end

    private

    def connect!
      @rd, @wr = ModdedIO.pipe

      @conn_thread = Thread.new do
        @mutex.synchronize { @connected = true }
        client.post('http://localhost:4321/v2/intake', body: @rd).flush
        @mutex.synchronize { @connected = false }
      end
    end
  end

  RSpec.describe Connection do
    describe '#initialize' do
      it { should_not be_connected }
      its(:client) { should be_a HTTP::Client }
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

        subject.close!

        expect(stub).to have_been_requested
      end
    end
  end

  class ModdedIO < IO
    def self.pipe(*args)
      rd, wr = super
      rd.define_singleton_method(:rewind) { nil }
      [rd, wr]
    end
  end

  class Transport
    def initialize(config)
      @connection = Connection.new

      @serializers = Struct.new(:transactions, :errors).new(
        Serializers::Transactions.new(config),
        Serializers::Errors.new(config)
      )
    end

    def submit(resource)
      serialized =
        case resource
        when Transaction
          @serializers.transactions.build(resource)
        else
          'null'
        end

      @connection.write serialized.to_json
    end

    def close!
      @connection.close!
    end
  end

  RSpec.describe Transport do
    describe 'initialize' do
    end

    describe '#submit' do
      it 'takes records and sends them off' do
        WebMock.disable!

        agent = Agent.new Config.new
        instrumenter = Instrumenter.new agent

        transport = Transport.new agent.config
        transaction = Transaction.new instrumenter, 'T' do |t|
          t.span 'span 1' do
          end
        end

        transport.submit transaction

        # sleep 1

        transport.close!

        expect(MockAPMServer.requests.length).to be 1
        expect(MockAPMServer.transactions.legnth).to be 1

        WebMock.enable!
      end
    end
  end
end
