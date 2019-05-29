# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  module Transport
    module Serializers
      RSpec.describe SpanSerializer do
        subject { described_class.new Config.new }

        describe '#build', :mock_time do
          let(:transaction) { Transaction.new.start }

          let(:trace_context) do
            TraceContext.parse("00-#{'1' * 32}-#{'2' * 16}-01")
          end

          let :span do
            Span.new(
              name: 'Span',
              transaction_id: transaction.id,
              trace_context: trace_context
            ).tap do |span|
              span.start
              travel 100
              span.stop
            end
          end

          let(:result) { subject.build(span) }

          it 'builds' do
            expect(result).to match(
              span: {
                id: /.{16}/,
                transaction_id: span.transaction_id,
                parent_id: span.parent_id,
                trace_id: span.trace_id,
                name: 'Span',
                type: 'custom',
                context: { sync: true },
                stacktrace: [],
                timestamp: 694_224_000_000_000,
                duration: 100
              }
            )
          end

          context 'with a context' do
            let(:span) do
              Span.new(
                name: 'Span',
                transaction_id: transaction.id,
                trace_context: trace_context,
                context: Span::Context.new(
                  db: { statement: 'asd' },
                  http: { url: 'dsa' }
                )
              )
            end

            it 'adds context object' do
              expect(result.dig(:span, :context, :db, :statement))
                .to be 'asd'
              expect(result.dig(:span, :context, :http, :url)).to be 'dsa'
            end
          end

          context 'with a large db.statement' do
            it 'truncates to 10k chars' do
              span = Span.new(
                name: 'Span',
                transaction_id: transaction.id,
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
        end
      end
    end
  end
end
