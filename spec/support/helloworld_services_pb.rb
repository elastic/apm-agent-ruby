# frozen_string_literal: true

require 'grpc'
require_relative 'helloworld_pb'

module Helloworld
  module Greeter
    # The greeting service definition.
    class Service

      include GRPC::GenericService

      self.marshal_class_method = :encode
      self.unmarshal_class_method = :decode
      self.service_name = 'helloworld.Greeter'

      # Sends a greeting
      rpc :SayHello, HelloRequest, HelloReply
    end

    Stub = Service.rpc_stub_class
  end
end
