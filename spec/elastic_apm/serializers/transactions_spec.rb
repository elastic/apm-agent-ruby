# frozen_string_literal: true

module ElasticAPM
  module Serializers
    RSpec.describe Transactions do
      subject { Transactions.new Config.new }
      before { allow(SecureRandom).to receive(:uuid) { '_RANDOM' } }

      describe '#build' do
        it 'builds a transaction without spans', :mock_time do
          transaction =
            Transaction.new(nil, 'GET /something', 'request') do
              travel 100
            end.done 200

          expect(subject.build([transaction])).to eq(
            "transactions": [
              {
                "id": '_RANDOM',
                "name": 'GET /something',
                "type": 'request',
                "result": '200',
                "duration": 100,
                "timestamp": Time.utc(1992, 1, 1).iso8601
              }
            ]
          )
        end

        it 'builds a transaction with nested spans', :mock_time do
          transaction =
            Transaction.new nil, 'GET /something', 'request' do |t|
              travel 10
              t.span 'app/views/users.html.erb', 'template' do
                travel 10
                t.span 'SELECT * FROM users', 'db.query' do
                  travel 10
                end
                travel 10
              end
              travel 10
            end.done 200

          expect(subject.build([transaction])).to eq(
            transactions: [
              {
                "id": '_RANDOM',
                "name": 'GET /something',
                "type": 'request',
                "result": '200',
                "duration": 50,
                "timestamp": Time.utc(1992, 1, 1).iso8601,
                "spans": [
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
