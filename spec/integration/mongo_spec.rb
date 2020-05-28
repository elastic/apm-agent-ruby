# Licensed to Elasticsearch B.V. under one or more contributor
# license agreements. See the NOTICE file distributed with
# this work for additional information regarding copyright
# ownership. Elasticsearch B.V. licenses this file to you under
# the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

# frozen_string_literal: true

require 'spec_helper'

require 'mongo'

module ElasticAPM
  RSpec.describe 'Spy: MongoDB' do
    let(:url) do
      ENV.fetch('MONGODB_URL') { '127.0.0.1:27017' }
    end

    it 'instruments db admin commands', :intercept do
      with_agent do
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

        client.close
      end

      span, = @intercepted.spans

      expect(span.name).to eq 'elastic-apm-test.listCollections'
      expect(span.type).to eq 'db'
      expect(span.subtype).to eq 'mongodb'
      expect(span.action).to eq 'query'
      expect(span.duration).to_not be_nil

      db = span.context.db
      expect(db.instance).to eq 'elastic-apm-test'
      expect(db.type).to eq 'mongodb'
      expect(db.statement).to include '{"listCollections"=>1, "cursor"=>{}, ' \
        '"nameOnly"=>true'
      expect(db.user).to be nil
    end

    it 'instruments commands on collections', :intercept do
      with_agent do
        client =
          Mongo::Client.new(
            [url],
            database: 'elastic-apm-test',
            logger: Logger.new(nil),
            server_selection_timeout: 5
          )

        client['testing'].drop
        client['testing'].create
        ElasticAPM.with_transaction 'Mongo test' do
          client['testing'].delete_many
        end

        client['testing'].drop
        client.close
      end

      span, = @intercepted.spans

      expect(span.name).to eq 'elastic-apm-test.testing.delete'
      expect(span.type).to eq 'db'
      expect(span.subtype).to eq 'mongodb'
      expect(span.action).to eq 'query'
      expect(span.duration).to_not be_nil

      db = span.context.db
      expect(db.instance).to eq 'elastic-apm-test'
      expect(db.type).to eq 'mongodb'
      expect(db.statement).to match('"delete"=>"testing"')
      expect(db.user).to be nil
    end

    it 'instruments commands with special BSON types', :intercept do
      with_agent do
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

        client.close
      end

      span, = @intercepted.spans

      expect(span.name).to eq 'elastic-apm-test.testing.find'
      expect(span.type).to eq 'db'
      expect(span.subtype).to eq 'mongodb'
      expect(span.action).to eq 'query'
      expect(span.duration).to_not be_nil

      db = span.context.db
      expect(db.instance).to eq 'elastic-apm-test'
      expect(db.type).to eq 'mongodb'
      expect(db.statement).to include '{"a"=>BSON::Decimal128(\'1\')}'
      expect(db.user).to be nil
    end

    it 'instruments getMore comments', :intercept do
      with_agent do
        client =
          Mongo::Client.new(
            [url],
            database: 'elastic-apm-test',
            logger: Logger.new(nil),
            server_selection_timeout: 5
          )

        3.times { |i| client['testing'].insert_one(a: i) }
        ElasticAPM.with_transaction 'Mongo test' do
          client['testing'].find({}, batch_size: 2).to_a
        end

        client.close
      end

      find_span, get_more_span = @intercepted.spans

      expect(find_span.name).to eq 'elastic-apm-test.testing.find'
      expect(find_span.type).to eq 'db'
      expect(find_span.subtype).to eq 'mongodb'
      expect(find_span.action).to eq 'query'
      expect(find_span.duration).to_not be_nil

      db = find_span.context.db
      expect(db.instance).to eq 'elastic-apm-test'
      expect(db.type).to eq 'mongodb'
      expect(db.statement).to include '{"find"=>"testing"'
      expect(db.user).to be nil

      expect(get_more_span.name).to eq 'elastic-apm-test.testing.getMore'
      expect(get_more_span.type).to eq 'db'
      expect(get_more_span.subtype).to eq 'mongodb'
      expect(get_more_span.action).to eq 'query'
      expect(get_more_span.duration).to_not be_nil

      db = get_more_span.context.db
      expect(db.instance).to eq 'elastic-apm-test'
      expect(db.type).to eq 'mongodb'
      expect(db.statement).to include '{"getMore"=>#<BSON::Int64'
      expect(db.user).to be nil
    end
  end
end
