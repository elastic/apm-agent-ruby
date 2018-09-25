# frozen_string_literal: true

module ElasticAPM
  module Transport
    module Serializers
      RSpec.describe TransactionSerializer do
        let(:builder) { described_class.new Config.new }

        before do
          @mock_uuid = SecureRandom.uuid
          allow(SecureRandom).to receive(:uuid) { @mock_uuid }
        end

        describe '#build', :mock_time do
          context 'a transaction without spans', :intercept do
            let(:transaction) do
              ElasticAPM.start
              ElasticAPM.with_transaction('GET /something', 'request') do |t|
                travel 100
                t.result = '200'
              end
              ElasticAPM.stop

              @intercepted.transactions.first
            end

            subject { builder.build(transaction) }

            it 'builds' do
              should match(
                transaction: {
                  "id": /.{16}/,
                  "name": 'GET /something',
                  "type": 'request',
                  "result": '200',
                  "context": { custom: {}, tags: {} },
                  "duration": 100.0,
                  "timestamp": 694_224_000_000_000,
                  "trace_id": transaction.trace_id,
                  "sampled": true,
                  "span_count": {
                    "started": 0,
                    "dropped": 0
                  },
                  "parent_id": nil
                }
              )
            end
          end

          context 'with dropped spans', :intercept do
            it 'includes count' do
              ElasticAPM.start(transaction_max_spans: 2)
              ElasticAPM.with_transaction 'T' do
                ElasticAPM.with_span('1') {}
                ElasticAPM.with_span('2') {}
                ElasticAPM.with_span('dropped') {}
              end
              ElasticAPM.stop

              transaction = @intercepted.transactions.first
              result = described_class.new(Config.new).build(transaction)

              span_count = result.dig(:transaction, :span_count)
              expect(span_count[:started]).to be 3
              expect(span_count[:dropped]).to be 1
            end
          end
        end
      end
    end
  end
end
