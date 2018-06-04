# frozen_string_literal: true

module ElasticAPM
  module Serializers
    RSpec.describe Transactions do
      let(:agent) { Agent.new(Config.new) }
      let(:instrumenter) { Instrumenter.new agent }
      let(:builder) { Transactions.new agent.config }
      before do
        @mock_uuid = SecureRandom.uuid
        allow(SecureRandom).to receive(:uuid) { @mock_uuid }
      end

      describe '#build', :mock_time do
        context 'a transaction without spans' do
          let(:transaction) do
            Transaction.new(instrumenter, 'GET /something', 'request') do
              travel 100
            end.done 200
          end
          subject { builder.build(transaction) }
          it 'builds' do
            should match(
              "id": @mock_uuid,
              "name": 'GET /something',
              "type": 'request',
              "result": '200',
              "context": { custom: {}, tags: {} },
              "duration": 100.0,
              "timestamp": Time.utc(1992, 1, 1).iso8601(3),
              "spans": [],
              "sampled": true
            )
          end
        end

        context 'a transaction with nested spans' do
          let(:transaction) do
            Transaction.new(instrumenter, 'GET /something', 'request') do |t|
              travel 10
              t.span 'app/views/users.html.erb', 'template' do
                travel 10
                context =
                  Span::Context.new(statement: 'BO SELECTA', type: 'sql')
                t.span 'SELECT * FROM users', 'db.sql', context: context do
                  travel 10
                end
                travel 10
              end
              travel 10
            end.done 200
          end

          subject { builder.build(transaction) }

          it 'builds' do
            should match(
              "id": @mock_uuid,
              "name": 'GET /something',
              "type": 'request',
              "result": '200',
              "context": { custom: {}, tags: {} },
              "duration": 50,
              "timestamp": Time.utc(1992, 1, 1).iso8601(3),
              "spans": [
                {
                  id: 0,
                  parent: nil,
                  name: 'app/views/users.html.erb',
                  type: 'template',
                  start: 10,
                  duration: 30,
                  context: nil,
                  stacktrace: Array
                }, {
                  id: 1,
                  parent: 0,
                  name: 'SELECT * FROM users',
                  type: 'db.sql',
                  start: 20,
                  duration: 10,
                  context: {
                    db: {
                      statement: 'BO SELECTA',
                      type: 'sql'
                    }
                  },
                  stacktrace: Array
                }
              ],
              sampled: true
            )
          end
        end

        context 'with dropped spans' do
          it 'includes count' do
            config = Config.new(transaction_max_spans: 2)
            agent = Agent.new(config)
            instrumenter = Instrumenter.new agent
            transaction = Transaction.new instrumenter, 'T' do |t|
              t.span '1'
              t.span '2'
              t.span 'dropped'
              t
            end

            result = Transactions.new(config).build(transaction)

            expect(result.dig(:span_count, :dropped, :total)).to be 1
          end
        end
      end
    end
  end
end
