# frozen_string_literal: true

module ElasticAPM
  module Transport
    module Serializers
      RSpec.describe SpanSerializer do
        let(:agent) { Agent.new(Config.new(disable_send: true)) }
        let(:instrumenter) { Instrumenter.new agent }
        let(:builder) { described_class.new agent.config }

        before do
          @mock_uuid = SecureRandom.uuid
          allow(SecureRandom).to receive(:uuid) { @mock_uuid }
        end

        describe '#build', :mock_time do
          context 'a span' do
            let :transaction do
              instrumenter.transaction do
                instrumenter.span('SELECT *', 'db.query') do
                  travel 100
                end
              end
            end

            let :span do
              transaction.spans.first
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
                  timestamp: @mocked_date,
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
