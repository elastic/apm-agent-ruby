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
            TraceContext.parse("00-#{'1' * 32}-#{'2' * 16}-01")
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
                timestamp: 694_224_000_000_000,
                duration: 10
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
                  labels: { foo: 'bar' }
                )
              )
            end

            it 'adds context object' do
              expect(result.dig(:span, :context, :db, :statement))
                .to eq 'asd'
              expect(result.dig(:span, :context, :http, :url)).to eq 'dsa'
              expect(result.dig(:span, :context, :sync)).to eq false
              expect(result.dig(:span, :context, :tags, :foo)).to eq 'bar'
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
                    name: 'a',
                    resource: 'b',
                    type: 'c',
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
        end
      end
    end
  end
end
