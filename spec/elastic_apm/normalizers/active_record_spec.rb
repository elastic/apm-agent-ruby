# frozen_string_literal: true

require 'elastic_apm/normalizers'
require 'elastic_apm/normalizers/rails'

module ElasticAPM
  module Normalizers
    module ActiveRecord
      RSpec.describe SqlNormalizer do
        it 'registers for name' do
          normalizers = Normalizers.build nil
          subject = normalizers.for('sql.active_record')
          expect(subject).to be_a SqlNormalizer
        end

        describe '#initialize' do
          unless defined? ::ActiveRecord::Base
            class ::ActiveRecord # rubocop:disable Style/ClassAndModuleChildren
              class Base; end
            end
          end

          it 'knows the AR adapter' do
            allow(::ActiveRecord::Base)
              .to receive(:connection_config) { { adapter: 'MySQL' } }

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
            allow(::ActiveRecord::Base)
              .to receive(:connection_config) { { adapter: nil } }
            sql = 'SELECT  "hotdogs".* FROM "hotdogs" ' \
              'WHERE "hotdogs"."topping" = $1 LIMIT 1'

            name, type, subtype, action, context_ = normalize_payload(sql: sql)
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

            _name, _type, subtype, = normalize_payload(
              sql: sql,
              connection: double(adapter_name: 'Postgres')
            )
            expect(subtype).to eq 'postgres'
          end

          it 'uses ActiveRecord::Base when payload is not available' do
            sql = 'SELECT  "burgers".* FROM "burgers" ' \
              'WHERE "burgers"."cheese" = $1 LIMIT 1'

            allow(::ActiveRecord::Base)
              .to receive(:connection_config) { { adapter: 'Postgres' } }
            _name, _type, subtype, = normalize_payload(sql: sql)

            expect(subtype).to eq 'postgres'

            allow(::ActiveRecord::Base)
              .to receive(:connection_config) { { adapter: '' } }
            _name, _type, subtype, = normalize_payload(sql: sql)

            expect(subtype).to eq 'unknown'

            allow(::ActiveRecord::Base)
              .to receive(:connection_config) { { adapter: nil } }
            _name, _type, subtype, = normalize_payload(sql: sql)

            expect(subtype).to eq 'unknown'
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
