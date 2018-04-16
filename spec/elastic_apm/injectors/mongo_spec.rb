require 'spec_helper'
require 'mongo'

module ElasticAPM
  RSpec.describe 'Injectors::MongoInjector' do
    it 'instruments calls', :with_fake_server do
      ElasticAPM.start flush_interval: nil

      client =
        Mongo::Client.new(
          ['127.0.0.1:27017'],
          database: 'elastic-apm-test',
          logger: Logger.new(nil)
        )

      transaction =
        ElasticAPM.transaction 'Mongo test' do
          client.database.collections
        end.submit 'ok'

      expect(transaction.spans.length).to be 1
      span, = transaction.spans

      expect(span.name).to eq :listCollections
      expect(span.type).to eq 'db.mongodb.query'
      expect(span.duration).to_not be_nil
      expect(span.context.to_h).to eq(
        instance: 'elastic-apm-test',
        type: 'mongodb',
        statement: nil,
        user: nil
      )

      wait_for_requests_to_finish 1

      client.close

      ElasticAPM.stop
    end
  end
end
