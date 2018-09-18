# frozen_string_literal: true

require 'mongo'

module ElasticAPM
  RSpec.describe 'Spy: MongoDB' do
    around do |ex|
      start_mongodb
      ex.run
      stop_mongodb
    end

    def stop_mongodb
      `docker-compose -f spec/docker-compose.yml down -v 2>&1`
    end

    def start_mongodb
      stop_mongodb
      `docker-compose -f spec/docker-compose.yml up -d mongodb 2>&1`
    end

    it 'instruments calls', :intercept do
      ElasticAPM.start

      url = ENV.fetch('MONGODB_URL') { '127.0.0.1:27017' }
      client =
        Mongo::Client.new(
          [url],
          database: 'elastic-apm-test',
          logger: Logger.new(nil),
          server_selection_timeout: 5
        )

      ElasticAPM.with_transaction 'Mongo test' do
        client.database.collections
      end

      span, = @intercepted.spans

      expect(span.name).to eq 'listCollections'
      expect(span.type).to eq 'db.mongodb.query'
      expect(span.duration).to_not be_nil
      expect(span.context.to_h).to eq(
        instance: 'elastic-apm-test',
        type: 'mongodb',
        statement: nil,
        user: nil
      )

      client.close

      ElasticAPM.stop
    end
  end
end
