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
                  id: '0',
                  transaction_id: @mock_uuid,
                  name: 'SELECT *',
                  type: 'db.query',
                  parent: nil,
                  context: nil,
                  stacktrace: [],
                  start: 0,
                  timestamp: Time.utc(1992, 1, 1).iso8601(3),
                  duration: 100,
                  trace_id: span.trace_id
                }
              )
            end
          end
        end
      end
    end
  end
end
