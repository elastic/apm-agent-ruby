# frozen_string_literal: true

require 'mongo'

module ElasticAPM
  RSpec.describe 'Spy: MongoDB' do
    before(:all) do
      start_mongodb
      ElasticAPM.start
    end

    after(:all) do
      ElasticAPM.stop
      stop_mongodb
    end

    def stop_mongodb
      `docker-compose -f spec/docker-compose.yml down -v 2>&1`
    end

    def start_mongodb
      stop_mongodb
      `docker-compose -f spec/docker-compose.yml up -d mongodb 2>&1`
    end

    let(:url) do
      ENV.fetch('MONGODB_URL') { '127.0.0.1:27017' }
    end

    it 'instruments db admin commands', :intercept do

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

      db = span.context.db
      expect(db.instance).to eq 'elastic-apm-test'
      expect(db.type).to eq 'mongodb'
      expect(db.statement).to be nil
      expect(db.user).to be nil

      client.close
    end

    it 'instruments commands on collections', :intercept do

      client =
        Mongo::Client.new(
          [url],
          database: 'elastic-apm-test',
          logger: Logger.new(nil),
          server_selection_timeout: 5
        )

      ElasticAPM.with_transaction 'Mongo test' do
        client['testing'].find.to_a
      end

      span, = @intercepted.spans

      expect(span.name).to eq 'find'
      expect(span.type).to eq 'db.mongodb.query'
      expect(span.duration).to_not be_nil

      db = span.context.db
      expect(db.instance).to eq 'elastic-apm-test'
      expect(db.type).to eq 'mongodb'
      expect(db.statement).to eq 'testing.find'
      expect(db.user).to be nil

      client.close
    end
  end
end
