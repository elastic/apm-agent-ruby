# frozen_string_literal: true

module ElasticAPM
  module Serializers
    RSpec.describe Transactions do
      subject { Transactions.new Config.new }

      describe '#build' do
        it 'builds a transaction without traces', :mock_time do
          agent = Agent.new Config.new

          transaction =
            Transaction.new(agent, 'GET /something', 'request') do
              travel 100
            end.submit('success')

          expect(subject.build([transaction])).to eq(
            "transactions": [
              {
                "id": '945254c5-67a5-417e-8a4e-aa29efcbfb79',
                "name": 'GET /something',
                "type": 'request',
                "result": 'success',
                "duration": 100,
                "timestamp": Time.utc(1992, 1, 1)
              }
            ]
          )
        end

        it 'builds a transaction with nested traces', :mock_time do
          agent = Agent.new Config.new

          transaction =
            Transaction.new agent, 'GET /something', 'request' do |t|
              travel 10
              t.trace 'app/views/users.html.erb', 'template' do
                travel 10
                t.trace 'SELECT * FROM users', 'db.query' do
                  travel 10
                end
                travel 10
              end
              travel 10
            end.submit('success')

          expect(subject.build([transaction])).to eq(
            transactions: [
              {
                "id": '945254c5-67a5-417e-8a4e-aa29efcbfb79',
                "name": 'GET /something',
                "type": 'request',
                "result": 'success',
                "duration": 50,
                "timestamp": Time.utc(1992, 1, 1),
                "traces": [
                  {
                    id: 0,
                    parent: nil,
                    name: 'app/views/users.html.erb',
                    type: 'template',
                    start: 10,
                    duration: 30
                  }, {
                    id: 1,
                    parent: 0,
                    name: 'SELECT * FROM users',
                    type: 'db.query',
                    start: 20,
                    duration: 10
                  }
                ]
              }
            ]
          )
        end
      end
    end
  end
end
