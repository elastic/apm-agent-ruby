# frozen_string_literal: true

module ElasticAPM
  module Serializers
    RSpec.describe Transactions do
      let(:builder) { Transactions.new Config.new }
      before do
        @mock_uuid = SecureRandom.uuid
        allow(SecureRandom).to receive(:uuid) { @mock_uuid }
      end

      describe '#build', :mock_time do
        context 'a transaction without spans' do
          let(:transaction) do
            Transaction.new(nil, 'GET /something', 'request') do
              travel 100
            end.done 200
          end
          subject { builder.build(transaction) }
          it 'builds' do
            should eq(
              "id": @mock_uuid,
              "name": 'GET /something',
              "type": 'request',
              "result": '200',
              "duration": 100.0,
              "timestamp": Time.utc(1992, 1, 1).iso8601,
              "spans": []
            )
          end
        end

        context 'a transaction with nested spans' do
          let(:transaction) do
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
          end

          subject { builder.build(transaction) }

          it 'builds' do
            should eq(
              "id": @mock_uuid,
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
            )
          end
        end
      end
    end
  end
end
