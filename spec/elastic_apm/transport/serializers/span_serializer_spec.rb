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
            let(:span) do
              t = instrumenter.transaction do
                instrumenter.span('SELECT *', 'db.query') do
                  travel 100
                end
              end

              t.spans.first
            end

            subject { builder.build(span) }

            it 'builds' do
              should match(
                span: {
                  id: 0,
                  name: 'SELECT *',
                  type: 'db.query',
                  parent: nil,
                  context: nil,
                  stacktrace: [],
                  start: 0,
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
