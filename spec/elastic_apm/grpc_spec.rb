# frozen_string_literal: true

module ElasticAPM
  RSpec.describe GRPC, :intercept do
    class GreeterServer < Helloworld::Greeter::Service
      def say_hello(hello_req, _unused_call)
        Helloworld::HelloReply.new(message: "Hello #{hello_req.name}")
      end
    end

    context 'client request' do
      let(:stub) do
        Helloworld::Greeter::Stub.new(
          'localhost:50051',
          :this_channel_is_insecure,
          interceptors: [ElasticAPM::GRPC::ClientInterceptor.new]
        )
      end

      it 'creates a span' do
        server = ::GRPC::RpcServer.new
        server.add_http2_port('0.0.0.0:50051', :this_port_is_insecure)
        server.handle(GreeterServer)
        thread = Thread.new { server.run }
        server.wait_till_running

        message = with_agent do
          stub.say_hello(Helloworld::HelloRequest.new(name: 'world')).message
        end
        expect(message).to eq('Hello world')
        expect(@intercepted.transactions.size).to eq(1)

        server.stop
        thread.kill
      end
    end
  end
end
