# frozen_string_literal: true

module ElasticAPM
  module Transport
    module Serializers
      RSpec.describe SpanSerializer do
        let(:builder) { described_class.new Config.new }

        before do
          @mock_uuid = SecureRandom.uuid
          allow(SecureRandom).to receive(:uuid) { @mock_uuid }
        end

        describe '#build', :mock_time, :intercept do
          context 'a span' do
            let :span do
              ElasticAPM.start
              ElasticAPM.with_transaction do
                ElasticAPM.with_span(
                  'SELECT *',
                  'db.query',
                  include_stacktrace: false
                ) { travel 100 }
              end
              ElasticAPM.stop

              @intercepted.spans.first
            end

            subject { builder.build(span) }

            it 'builds' do
              should match(
                span: {
                  id: /.{16}/,
                  transaction_id: span.transaction_id,
                  parent_id: span.parent_id,
                  trace_id: span.trace_id,
                  name: 'SELECT *',
                  type: 'db.query',
                  context: nil,
                  stacktrace: [],
                  start: 0,
                  timestamp: 694_224_000_000_000,
                  duration: 100
                }
              )
            end
          end
        end
      end
    end
  end
end
