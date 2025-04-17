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

# frozen_string_literal: true

require 'spec_helper'

# if !defined?(JRUBY_VERSION) && RUBY_VERSION >= '3.0'
#   require 'grpc'
#
#   module ElasticAPM
#     RSpec.describe GRPC, :intercept do
#       class GreeterServer < Helloworld::Greeter::Service
#         def say_hello(hello_req, _unused_call)
#           Helloworld::HelloReply.new(message: "Hello #{hello_req.name}")
#         end
#       end
#
#       describe GRPC::ClientInterceptor do
#         let(:stub) do
#           Helloworld::Greeter::Stub.new(
#             'localhost:50051',
#             :this_channel_is_insecure,
#             interceptors: [described_class.new]
#           )
#         end
#
#         let(:server) do
#           ::GRPC::RpcServer.new.tap do |s|
#             s.add_http2_port('0.0.0.0:50051', :this_port_is_insecure)
#             s.handle(GreeterServer)
#           end
#         end
#
#         it 'creates a span' do
#           thread = Thread.new { server.run }
#           # Sometimes the gRPC server doesn't start so we skip the test
#           skip 'gRPC is not running' unless server.wait_till_running
#
#           message = with_agent do
#             ElasticAPM.with_transaction 'GRPC test' do
#               stub.say_hello(
#                 Helloworld::HelloRequest.new(name: 'goodbye')
#               ).message
#             end
#           end
#           expect(message).to eq('Hello goodbye')
#
#           span, = @intercepted.spans
#           expect(span.name).to eq('/helloworld.Greeter/SayHello')
#           expect(span.type).to eq('external')
#           expect(span.subtype).to eq('grpc')
#           expect(span.context.destination.type).to eq('external')
#           expect(span.context.destination.name).to eq('grpc')
#           expect(span.context.destination.resource).to eq('localhost:50051')
#           expect(span.context.destination.address).to eq('localhost')
#           expect(span.context.destination.port).to eq('50051')
#
#           server.stop
#           thread.kill
#         end
#
#         context 'when the transaction is not sampled' do
#           let(:config) { { transaction_sample_rate: 0.0 } }
#
#           it 'does not create a span' do
#             thread = Thread.new { server.run }
#             # Sometimes the gRPC server doesn't start so we skip the test
#             skip 'gRPC is not running' unless server.wait_till_running
#
#             message = with_agent(**config) do
#               ElasticAPM.with_transaction 'GRPC test' do
#                 stub.say_hello(
#                   Helloworld::HelloRequest.new(name: 'goodbye')
#                 ).message
#               end
#             end
#             expect(message).to eq('Hello goodbye')
#             expect(@intercepted.spans.size).to eq(0)
#
#             server.stop
#             thread.kill
#           end
#         end
#
#         context 'when no transaction is started' do
#           let(:config) { { transaction_sample_rate: 0.0 } }
#
#           it 'does not create a span' do
#             thread = Thread.new { server.run }
#             # Sometimes the gRPC server doesn't start so we skip the test
#             skip 'gRPC is not running' unless server.wait_till_running
#
#             message = with_agent do
#               stub.say_hello(
#                 Helloworld::HelloRequest.new(name: 'goodbye')
#               ).message
#             end
#             expect(message).to eq('Hello goodbye')
#             expect(@intercepted.spans.size).to eq(0)
#             expect(@intercepted.transactions.size).to eq(0)
#
#             server.stop
#             thread.kill
#           end
#         end
#
#         context 'when max spans is reached' do
#           let(:config) { { transaction_max_spans: 1 } }
#
#           it 'does not create a span' do
#             thread = Thread.new { server.run }
#             # Sometimes the gRPC server doesn't start so we skip the test
#             skip 'gRPC is not running' unless server.wait_till_running
#
#             message = with_agent(**config) do
#               ElasticAPM.with_transaction 'GRPC test' do
#                 stub.say_hello(
#                   Helloworld::HelloRequest.new(name: 'bonjour')
#                 ).message
#                 stub.say_hello(
#                   Helloworld::HelloRequest.new(name: 'goodbye')
#                 ).message
#               end
#             end
#             expect(message).to eq('Hello goodbye')
#             expect(@intercepted.spans.size).to eq(1)
#             expect(@intercepted.transactions.size).to eq(1)
#
#             server.stop
#             thread.kill
#           end
#         end
#
#         context 'trace_context' do
#           let(:trace_context) { TraceContext.new(trace_id: '123') }
#           it 'passes it to the span' do
#             thread = Thread.new { server.run }
#             # Sometimes the gRPC server doesn't start so we skip the test
#             skip 'gRPC is not running' unless server.wait_till_running
#
#             message = with_agent do
#               ElasticAPM.with_transaction(
#                 'GRPC test', trace_context: trace_context
#               ) do
#                 stub.say_hello(
#                   Helloworld::HelloRequest.new(name: 'goodbye')
#                 ).message
#               end
#             end
#             expect(message).to eq('Hello goodbye')
#
#             span, = @intercepted.spans
#             expect(span.trace_id).to eq('123')
#
#             server.stop
#             thread.kill
#           end
#         end
#       end
#
#       describe GRPC::ServerInterceptor do
#         let(:stub) do
#           Helloworld::Greeter::Stub.new(
#             'localhost:50051',
#             :this_channel_is_insecure
#           )
#         end
#
#         let(:server) do
#           ::GRPC::RpcServer.new(
#             interceptors: [described_class.new]
#           ).tap do |s|
#             s.add_http2_port('0.0.0.0:50051', :this_port_is_insecure)
#             s.handle(GreeterServer)
#           end
#         end
#
#         it 'creates a transaction' do
#           thread = Thread.new { server.run }
#           # Sometimes the gRPC server doesn't start so we skip the test
#           skip 'gRPC is not running' unless server.wait_till_running
#
#           message = with_agent do
#             stub.say_hello(
#               Helloworld::HelloRequest.new(name: 'goodbye')
#             ).message
#           end
#           expect(message).to eq('Hello goodbye')
#
#           transaction, = @intercepted.transactions
#           expect(transaction.name).to eq('grpc')
#           expect(transaction.type).to eq('request')
#           expect(transaction.result).to eq('success')
#
#           server.stop
#           thread.kill
#         end
#
#         context 'trace_context' do
#           let(:trace_context) do
#             TraceContext.parse("00-#{'1' * 32}-#{'2' * 16}-01")
#           end
#
#           it 'sets it on the transaction' do
#             thread = Thread.new { server.run }
#             # Sometimes the gRPC server doesn't start so we skip the test
#             skip 'gRPC is not running' unless server.wait_till_running
#
#             message = with_agent do
#               stub.say_hello(
#                 Helloworld::HelloRequest.new(name: 'goodbye'),
#                 metadata: {}.tap do |m|
#                   trace_context.apply_headers { |k, v| m[k.downcase] = v }
#                 end
#               ).message
#             end
#             expect(message).to eq('Hello goodbye')
#
#             transaction, = @intercepted.transactions
#             expect(transaction.name).to eq('grpc')
#             expect(transaction.type).to eq('request')
#             expect(transaction.result).to eq('success')
#             expect(transaction.trace_id).to eq(trace_context.trace_id)
#             expect(transaction.parent_id).to eq(trace_context.id)
#
#             server.stop
#             thread.kill
#           end
#
#           context 'with tracestate' do
#             before do
#               trace_context.tracestate = TraceContext::Tracestate.parse('a=b')
#             end
#
#             it 'sets it on the transaction' do
#               thread = Thread.new { server.run }
#               # Sometimes the gRPC server doesn't start so we skip the test
#               skip 'gRPC is not running' unless server.wait_till_running
#
#               message = with_agent do
#                 stub.say_hello(
#                   Helloworld::HelloRequest.new(name: 'goodbye'),
#                   metadata: {}.tap do |m|
#                     trace_context.apply_headers { |k, v| m[k.downcase] = v }
#                   end
#                 ).message
#               end
#               expect(message).to eq('Hello goodbye')
#
#               transaction, = @intercepted.transactions
#               expect(transaction.name).to eq('grpc')
#               expect(transaction.type).to eq('request')
#               expect(transaction.result).to eq('success')
#               expect(transaction.trace_id).to eq(trace_context.trace_id)
#               expect(transaction.parent_id).to eq(trace_context.id)
#               expect(transaction.trace_context.tracestate.values)
#                 .to eq(['a=b'])
#
#               server.stop
#               thread.kill
#             end
#           end
#         end
#
#         context 'when there\'s and error' do
#           class FancyError < ::StandardError; end
#
#           class GreeterErrorServer < Helloworld::Greeter::Service
#             def say_hello(hello_req, _unused_call)
#               raise FancyError, 'boom!'
#             end
#           end
#
#           let(:server) do
#             ::GRPC::RpcServer.new(
#               interceptors: [described_class.new]
#             ).tap do |s|
#               s.add_http2_port('0.0.0.0:50051', :this_port_is_insecure)
#               s.handle(GreeterErrorServer)
#             end
#           end
#
#           if Thread.respond_to?(:report_on_exception)
#             around do |example|
#               # This is necessary, otherwise there will be a warning
#               # that the server thread died because of an exception.
#               original_value = Thread.report_on_exception
#               Thread.report_on_exception = false
#               example.run
#               Thread.report_on_exception = original_value
#             end
#           end
#
#           it 'reports the error', :mock_time do
#             thread = Thread.new { server.run }
#             # Sometimes the gRPC server doesn't start so we skip the test
#             skip 'gRPC is not running' unless server.wait_till_running
#
#             expect do
#               with_agent do
#                 stub.say_hello(Helloworld::HelloRequest.new(name: 'goodbye'))
#               end
#             end.to raise_exception(Exception)
#
#             transaction, = @intercepted.transactions
#             expect(transaction.name).to eq('grpc')
#             expect(transaction.type).to eq('request')
#             expect(transaction.result).to eq('error')
#
#             error, = @intercepted.errors
#             expect(error.culprit).to eq 'say_hello'
#             expect(error.timestamp).to eq 694_224_000_000_000
#             expect(error.exception.message).to eq 'boom!'
#             expect(error.exception.type).to eq 'ElasticAPM::FancyError'
#             expect(error.exception.handled).to be false
#
#             server.stop
#             thread.kill
#           end
#         end
#       end
#     end
#   end
# end
