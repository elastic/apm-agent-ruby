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

module ElasticAPM
  module Transport
    module Serializers
      RSpec.describe SpanSerializer do
        let(:config) { Config.new }
        subject { described_class.new config }

        describe '#build', :mock_time do
          let(:transaction) { Transaction.new(config: config).start }

          let(:trace_context) do
            traceparent =
              TraceContext::Traceparent.parse("00-#{'1' * 32}-#{'2' * 16}-01")
            TraceContext.new(traceparent: traceparent)
          end

          let :span do
            Span.new(
              name: 'Span',
              transaction: transaction,
              parent: transaction,
              trace_context: trace_context,
              sync: true
            ).tap do |span|
              span.start
              travel 10_000
              span.stop
            end
          end

          let(:result) { subject.build(span) }

          it 'builds' do
            expect(result).to match(
              span: {
                id: /.{16}/,
                transaction_id: transaction.id,
                parent_id: span.parent_id,
                trace_id: span.trace_id,
                name: 'Span',
                type: 'custom',
                context: { sync: true },
                stacktrace: [],
                sample_rate: 1,
                timestamp: 694_224_000_000_000,
                duration: 10,
                outcome: nil
              }
            )
          end

          context 'with a context' do
            let(:span) do
              Span.new(
                name: 'Span',
                transaction: transaction,
                parent: transaction,
                trace_context: trace_context,
                context: Span::Context.new(
                  db: { statement: 'asd' },
                  http: { url: 'dsa' },
                  sync: false,
                  labels: { foo: 'bar' },
                  service: {target: {name: 'test'}}
                )
              )
            end

            it 'adds context object' do
              expect(result.dig(:span, :context, :db, :statement))
                .to eq 'asd'
              expect(result.dig(:span, :context, :http, :url)).to eq 'dsa'
              expect(result.dig(:span, :context, :sync)).to eq false
              expect(result.dig(:span, :context, :tags, :foo)).to eq 'bar'
              expect(result.dig(:span, :context, :service, :target, :name)).to eq 'test'
            end

            context 'with rows_affected' do
              let(:span) do
                Span.new(
                  name: 'Span',
                  transaction: transaction,
                  parent: transaction,
                  trace_context: trace_context,
                  context: Span::Context.new(
                    db: { rows_affected: 2 }
                  )
                )
              end

              it 'adds rows_affected' do
                expect(result.dig(:span, :context, :db, :rows_affected))
                  .to eq 2
              end
            end

            context 'when sync is nil' do
              let(:span) do
                Span.new(
                  name: 'Span',
                  transaction: transaction,
                  parent: transaction,
                  trace_context: trace_context,
                  context: Span::Context.new(
                    db: { statement: 'asd' },
                    http: { url: 'dsa' }
                  )
                )
              end

              it 'adds context object' do
                expect(result.dig(:span, :context, :db, :statement))
                  .to eq 'asd'
                expect(result.dig(:span, :context, :http, :url)).to eq 'dsa'
                expect(result[:span][:context].key?(:sync)).to be false
              end
            end
          end

          context 'with a destination' do
            it 'adds destination object' do
              span = Span.new(
                name: 'Span',
                transaction: transaction,
                parent: transaction,
                trace_context: trace_context,
                context: Span::Context.new(
                  destination: {
                    service: {
                      name: 'a',
                      resource: 'b',
                      type: 'c',
                    },
                    address: 'd',
                    port: 8080
                  }
                )
              )

              result = subject.build(span)

              expect(result.dig(:span, :context, :destination)).to match(
                {
                  service: {
                    name: 'a',
                    resource: 'b',
                    type: 'c'
                  },
                  address: 'd',
                  port: 8080
                }
              )
            end
          end

          context 'with a message' do
            it 'adds message object' do
              span = Span.new(
                name: 'Span',
                transaction: transaction,
                parent: transaction,
                trace_context: trace_context,
                context: Span::Context.new(
                  message: {
                    queue_name: 'my_queue',
                    age_ms: 1000
                  }
                )
              )

              result = subject.build(span)

              expect(result.dig(:span, :context, :message)).to match(
                {
                  queue: {
                    name: 'my_queue'
                  },
                  age: {
                    ms: 1000
                  }
                 }
               )
            end
          end

          context 'with a large db.statement' do
            it 'truncates to 10k chars' do
              span = Span.new(
                name: 'Span',
                transaction: transaction,
                parent: transaction,
                trace_context: trace_context,
                context: Span::Context.new(
                  db: { statement: 'X' * 11_000 }
                )
              )

              result = subject.build(span)

              statement = result.dig(:span, :context, :db, :statement)
              expect(statement.length).to be(10_000)
            end
          end

          context 'with split types' do
            let(:span) do
              Span.new(
                name: 'Span',
                transaction: transaction,
                parent: transaction,
                trace_context: trace_context,
                type: 'a',
                subtype: 'b',
                action: 'c'
              )
            end

            it 'joins them for sending' do
              expect(result[:span][:type]).to eq 'a.b.c'
            end
          end

          context 'with outcome' do
            it 'adds the outcome' do
              span = Span.new(
                name: 'Span',
                transaction: transaction,
                parent: transaction,
                trace_context: trace_context
              )

              span.outcome = 'success'
              result = subject.build(span)
              expect(result[:span][:outcome]).to eq 'success'
            end
          end

          context 'with a destination and cloud' do
            it 'adds destination with cloud' do
              span = Span.new(
                name: 'Span',
                transaction: transaction,
                parent: transaction,
                trace_context: trace_context,
                context: Span::Context.new(
                  destination: {
                    service: { resource: 'a' },
                    cloud: { region: 'b' }
                  }
                )
              )

              # set auto-infered destination.service fields
              span.start.done

              result = subject.build(span)

              expect(result.dig(:span, :context, :destination, :service))
                .to match({ resource: 'a', name: '', type: '' })

              expect(result.dig(:span, :context, :destination, :cloud))
                .to match({ region: 'b' })
            end
          end
        end
      end
    end
  end
end
