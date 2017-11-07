# frozen_string_literal: true

module ElasticAPM
  module Serializers
    RSpec.describe Transactions do
      subject { Transactions.new Config.new }

      describe '#build' do
        it 'transforms the simplest of transactions', :mock_time do
          agent = Agent.new Config.new

          transaction =
            Transaction.new(agent, 'GET /something', 'request') do |t|
              travel 100
            end.submit(:success)

          result = subject.build([transaction])
          expected = {
            "transactions": [
              {
                "id": '945254c5-67a5-417e-8a4e-aa29efcbfb79',
                "name": 'GET /something',
                "type": 'request',
                "result": 'success',
                "duration": 100,
                "timestamp": Time.current
              }
            ]
          }

          pp result
          pp '=' * 80
          pp expected

          expect(result).to eq expected
        end
      end
    end
  end
end
