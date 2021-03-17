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

require 'elastic_apm/normalizers'
require 'elastic_apm/normalizers/rails'

module ElasticAPM
  module Normalizers
    module ActiveRecord
      RSpec.describe SqlNormalizer do
        before do
          unless defined? ::ActiveRecord::Base
            class ::ActiveRecord
              class Base; end
            end
          end
        end

        it 'registers for name' do
          normalizers = Normalizers.build nil
          subject = normalizers.for('sql.active_record')
          expect(subject).to be_a SqlNormalizer
        end

        describe '#initialize' do
          it 'knows the AR adapter' do
            allow(::ActiveRecord::Base).to receive(:connection_config) do
              { adapter: 'MySQL' }
            end

            subject = SqlNormalizer.new nil

            _, _, subtype, =
              subject.normalize(nil, nil, sql: 'DROP * FROM users')

            expect(subtype).to eq 'mysql'
          end
        end

        describe '#normalize' do
          let(:key) { 'sql.active_record' }
          subject { SqlNormalizer.new nil }

          def normalize_payload(payload)
            subject.normalize(nil, 'sql.active_record', payload)
          end

          it 'normalizes queries' do
            sql = 'SELECT  "hotdogs".* FROM "hotdogs" ' \
              'WHERE "hotdogs"."topping" = $1 LIMIT 1'

            name, type, subtype, action, context_ = normalize_payload(
              sql: sql,
              connection: double(adapter_name: '')
            )
            expect(name).to eq 'SELECT FROM hotdogs'
            expect(type).to eq 'db'
            expect(subtype).to eq 'unknown'
            expect(action).to eq 'sql'
            expect(context_.db.statement).to eq sql
          end

          it 'uses the connection from payload, when it\'s available' do
            sql = 'SELECT  "burgers".* FROM "burgers" ' \
              'WHERE "burgers"."cheese" = $1 LIMIT 1'

            _name, _type, subtype, = normalize_payload(
              sql: sql,
              connection: double(adapter_name: 'MySQL')
            )
            expect(subtype).to eq 'mysql'
          end

          it 'resolves the connection_id object id to a connection if the full ' \
               'connection is missing', unless: RSpec::Support::Ruby.jruby? do
            sql = 'SELECT  "burgers".* FROM "burgers" ' \
              'WHERE "burgers"."cheese" = $1 LIMIT 1'

            _name, _type, subtype, = normalize_payload(
              sql: sql,
              connection_id: double(adapter_name: 'MySQL').object_id
            )
            expect(subtype).to eq 'mysql'
          end

          it 'uses the connection from payload even if the connection_id ' \
               'is available' do
            sql = 'SELECT  "burgers".* FROM "burgers" ' \
              'WHERE "burgers"."cheese" = $1 LIMIT 1'

            _name, _type, subtype, = normalize_payload(
              sql: sql,
              connection: double(adapter_name: 'MySQL'),
              connection_id: double(adapter_name: 'wrong_db').object_id
            )
            expect(subtype).to eq 'mysql'
          end

          it 'handles a connection_id which loads an object that is not ' \
               'a connection', unless: RSpec::Support::Ruby.jruby? do
            allow(::ActiveRecord::Base).to receive(:connection_config) do
              { adapter: nil }
            end

            sql = 'SELECT  "burgers".* FROM "burgers" ' \
            'WHERE "burgers"."cheese" = $1 LIMIT 1'

            _name, _type, subtype, = normalize_payload(
              sql: sql,
              connection_id: double('does not respond to #adapter_name').object_id
            )

            expect(::ActiveRecord::Base)
              .to have_received(:connection_config)
            expect(subtype).to eq "unknown"
          end

          it 'handles a missing connection and connection_id value' do
            allow(::ActiveRecord::Base)
              .to receive(:connection_config) { { adapter: nil } }
            sql = 'SELECT  "burgers".* FROM "burgers" ' \
            'WHERE "burgers"."cheese" = $1 LIMIT 1'

            _name, _type, subtype, = normalize_payload(sql: sql)

            expect(::ActiveRecord::Base)
              .to have_received(:connection_config)
            expect(subtype).to eq "unknown"
          end

          it 'skips cache queries' do
            result =
              normalize_payload(name: 'CACHE', sql: 'DROP * FROM users')
            expect(result).to be :skip
          end
        end
      end
    end
  end
end
