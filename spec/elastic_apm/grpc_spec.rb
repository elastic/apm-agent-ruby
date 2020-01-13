# frozen_string_literal: true

require 'grpc'

module ElasticAPM
  RSpec.describe GRPC, :intercept do
    class GreeterServer < Helloworld::Greeter::Service
      def say_hello(hello_req, _unused_call)
        Helloworld::HelloReply.new(message: "Hello #{hello_req.name}")
      end
    end

    describe GRPC::ClientInterceptor do
      let(:stub) do
        Helloworld::Greeter::Stub.new(
          'localhost:50051',
          :this_channel_is_insecure,
          interceptors: [described_class.new]
        )
      end

      let(:server) do
        ::GRPC::RpcServer.new.tap do |s|
          s.add_http2_port('0.0.0.0:50051', :this_port_is_insecure)
          s.handle(GreeterServer)
        end
      end

      it 'creates a span' do
        thread = Thread.new { server.run }
        server.wait_till_running

        message = with_agent do
          ElasticAPM.with_transaction 'GRPC test' do
            stub.say_hello(
              Helloworld::HelloRequest.new(name: 'goodbye')
            ).message
          end
        end
        expect(message).to eq('Hello goodbye')

        span, = @intercepted.spans
        expect(span.name).to eq('/helloworld.Greeter/SayHello')
        expect(span.type).to eq('external')
        expect(span.subtype).to eq('grpc')

        server.stop
        thread.kill
      end

      context 'when the transaction is not sampled' do
        let(:config) { { transaction_sample_rate: 0.0 } }

        it 'does not create a span' do
          thread = Thread.new { server.run }
          server.wait_till_running

          message = with_agent(**config) do
            ElasticAPM.with_transaction 'GRPC test' do
              stub.say_hello(
                Helloworld::HelloRequest.new(name: 'goodbye')
              ).message
            end
          end
          expect(message).to eq('Hello goodbye')
          expect(@intercepted.spans.size).to eq(0)

          server.stop
          thread.kill
        end
      end

      context 'when no transaction is started' do
        let(:config) { { transaction_sample_rate: 0.0 } }

        it 'does not create a span' do
          thread = Thread.new { server.run }
          server.wait_till_running

          message = with_agent do
            stub.say_hello(
              Helloworld::HelloRequest.new(name: 'goodbye')
            ).message
          end
          expect(message).to eq('Hello goodbye')
          expect(@intercepted.spans.size).to eq(0)
          expect(@intercepted.transactions.size).to eq(0)

          server.stop
          thread.kill
        end
      end

      context 'when max spans is reached' do
        let(:config) { { transaction_max_spans: 1 } }

        it 'does not create a span' do
          thread = Thread.new { server.run }
          server.wait_till_running

          message = with_agent(**config) do
            ElasticAPM.with_transaction 'GRPC test' do
              stub.say_hello(
                Helloworld::HelloRequest.new(name: 'bonjour')
              ).message
              stub.say_hello(
                Helloworld::HelloRequest.new(name: 'goodbye')
              ).message
            end
          end
          expect(message).to eq('Hello goodbye')
          expect(@intercepted.spans.size).to eq(1)
          expect(@intercepted.transactions.size).to eq(1)

          server.stop
          thread.kill
        end
      end

      context 'trace_context' do
        let(:trace_context) { TraceContext.new(trace_id: '123') }
        it 'passes it to the span' do
          thread = Thread.new { server.run }
          server.wait_till_running

          message = with_agent do
            ElasticAPM.with_transaction(
              'GRPC test', { trace_context: trace_context }
            ) do
              stub.say_hello(
                Helloworld::HelloRequest.new(name: 'goodbye')
              ).message
            end
          end
          expect(message).to eq('Hello goodbye')

          span, = @intercepted.spans
          expect(span.trace_id).to eq('123')

          server.stop
          thread.kill
        end
      end
    end

    describe GRPC::ServerInterceptor do
      let(:stub) do
        Helloworld::Greeter::Stub.new(
          'localhost:50051',
          :this_channel_is_insecure
        )
      end

      let(:server) do
        ::GRPC::RpcServer.new(
          interceptors: [ElasticAPM::GRPC::ServerInterceptor.new]
        ).tap do |s|
          s.add_http2_port('0.0.0.0:50051', :this_port_is_insecure)
          s.handle(GreeterServer)
        end
      end

      it 'creates a transaction' do
        thread = Thread.new { server.run }
        server.wait_till_running

        message = with_agent do
          stub.say_hello(
            Helloworld::HelloRequest.new(name: 'goodbye')
          ).message
        end
        expect(message).to eq('Hello goodbye')

        transaction, = @intercepted.transactions
        expect(transaction.name).to eq('grpc')
        expect(transaction.type).to eq('request')

        server.stop
        thread.kill
      end

      context 'trace_context' do
        let(:trace_context) do
          TraceContext.parse("00-#{'1' * 32}-#{'2' * 16}-01")
        end

        it 'sets it on the transaction' do
          thread = Thread.new { server.run }
          server.wait_till_running

          message = with_agent do
            stub.say_hello(
              Helloworld::HelloRequest.new(name: 'goodbye'),
              metadata: { 'elastic-apm-traceparent' => trace_context.to_header }
            ).message
          end
          expect(message).to eq('Hello goodbye')

          transaction, = @intercepted.transactions
          expect(transaction.name).to eq('grpc')
          expect(transaction.type).to eq('request')
          expect(transaction.trace_id).to eq(trace_context.trace_id)
          expect(transaction.parent_id).to eq(trace_context.id)

          server.stop
          thread.kill
        end
      end
    end
  end
end
