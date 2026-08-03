# Licensed to Elasticsearch B.V. under one or more contributor
# license agreements. See the NOTICE file distributed with
# this work for additional information regarding copyright
# ownership. Elasticsearch B.V. licenses this file to you under
# the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

# Copyright 2017 gRPC authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# frozen_string_literal: true

# if !defined?(JRUBY_VERSION) && RUBY_VERSION < '3.0'
#   require_relative 'helloworld_pb'
#
#   module Helloworld
#     module Greeter
#       # The greeting service definition.
#       class Service
#         include GRPC::GenericService
#
#         self.marshal_class_method = :encode
#         self.unmarshal_class_method = :decode
#         self.service_name = 'helloworld.Greeter'
#
#         # Sends a greeting
#         rpc :SayHello, HelloRequest, HelloReply
#       end
#
#       Stub = Service.rpc_stub_class
#     end
#   end
# end
