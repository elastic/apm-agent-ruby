# frozen_string_literal: true

require 'mongo'

module ElasticAPM
  RSpec.describe 'Spy: MongoDB' do
    before(:context) do
      start_mongodb
    end

    after(:context) do
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
      ElasticAPM.start
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

      expect(span.name).to eq 'elastic-apm-test.listCollections'
      expect(span.type).to eq 'db.mongodb.query'
      expect(span.duration).to_not be_nil

      db = span.context.db
      expect(db.instance).to eq 'elastic-apm-test'
      expect(db.type).to eq 'mongodb'
      expect(db.statement).to include '{"listCollections"=>1, "cursor"=>{}, ' \
        '"nameOnly"=>true'
      expect(db.user).to be nil

      client.close

      ElasticAPM.stop
    end

    it 'instruments commands on collections', :intercept do
      ElasticAPM.start
      client =
        Mongo::Client.new(
          [url],
          database: 'elastic-apm-test',
          logger: Logger.new(nil),
          server_selection_timeout: 5
        )

      # ParallelCollectionScan can only be run on an existing collection.
      client['testing'].drop
      client['testing'].create
      ElasticAPM.with_transaction 'Mongo test' do
        client['testing'].parallel_scan(1).to_a
      end

      span, = @intercepted.spans

      expect(span.name).to eq 'elastic-apm-test.testing.parallelCollectionScan'
      expect(span.type).to eq 'db.mongodb.query'
      expect(span.duration).to_not be_nil

      db = span.context.db
      expect(db.instance).to eq 'elastic-apm-test'
      expect(db.type).to eq 'mongodb'
      # ParallelCollectionScan doesn't send 'lsid' in the command so we can
      # validate the entire command document.
      expect(db.statement).to eq '{"parallelCollectionScan"=>"testing", ' \
        '"numCursors"=>1}'
      expect(db.user).to be nil

      client['testing'].drop
      client.close

      ElasticAPM.stop
    end

    it 'instruments commands with special BSON types', :intercept do
      ElasticAPM.start
      client =
        Mongo::Client.new(
          [url],
          database: 'elastic-apm-test',
          logger: Logger.new(nil),
          server_selection_timeout: 5
        )

      ElasticAPM.with_transaction 'Mongo test' do
        client['testing'].find(a: BSON::Decimal128.new('1')).to_a
      end

      span, = @intercepted.spans

      expect(span.name).to eq 'elastic-apm-test.testing.find'
      expect(span.type).to eq 'db.mongodb.query'
      expect(span.duration).to_not be_nil

      db = span.context.db
      expect(db.instance).to eq 'elastic-apm-test'
      expect(db.type).to eq 'mongodb'
      expect(db.statement).to include '{"a"=>BSON::Decimal128(\'1\')}'
      expect(db.user).to be nil

      client.close

      ElasticAPM.stop
    end
  end
end
