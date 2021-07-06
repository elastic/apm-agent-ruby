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
require 'sequel'

module ElasticAPM
  RSpec.describe 'Spy: Sequel' do
    it 'spans calls', :intercept do
      db =
        if RUBY_PLATFORM == 'java'
          ::Sequel.connect('jdbc:sqlite::memory:')
        else
          ::Sequel.sqlite # in-memory
        end

      db.create_table :users do
        primary_key :id
        String :name
      end

      db[:users].count # warm up

      with_agent do
        ElasticAPM.with_transaction 'Sequel test' do
          db[:users].count
        end
      end

      span, = @intercepted.spans

      expect(span.name).to eq 'SELECT FROM users'
      expect(span.outcome).to eq 'success'
      expect(span.context.db.statement)
        .to eq "SELECT count(*) AS 'count' FROM `users` LIMIT 1"

      destination = span.context.destination
      expect(destination.service.resource).to eq 'sqlite'
    end

    it 'captures rows_affected for update and delete operations', :intercept do
      db =
        if RUBY_PLATFORM == 'java'
          ::Sequel.connect('jdbc:sqlite::memory:')
        else
          ::Sequel.sqlite # in-memory
        end

      db.create_table :customers do
        primary_key :id
        String :name
      end

      with_agent do
        ElasticAPM.with_transaction 'Sequel rows_affected test INSERT' do
          3.times do |i|
            db[:customers].insert(name: "customer_#{i}")
          end
        end

        spans = @intercepted.spans
        expect(spans.all? { |s| s.context.db.rows_affected.nil? }).to eq(true)
        expect(spans.all? { |s| s.outcome == 'success' }).to eq(true)

        ElasticAPM.with_transaction 'Sequel rows_affected test UPDATE' do
          db[:customers].where(name: 'customer_0').update(name: 'customer_zero')
        end

        span = @intercepted.spans.last
        expect(span.context.db.rows_affected).to eq(1)

        ElasticAPM.with_transaction 'Sequel rows_affected test DELETE' do
          db[:customers].delete
        end
        span = @intercepted.spans.last
        expect(span.context.db.rows_affected).to eq(3)
      end
    end

    context 'when the operation fails', :intercept do
      it 'adds `failure` outcome to the span' do
        db =
          if RUBY_PLATFORM == 'java'
            ::Sequel.connect('jdbc:sqlite::memory:')
          else
            ::Sequel.sqlite # in-memory
          end

        with_agent do
          ElasticAPM.with_transaction 'Sequel failure test' do
            begin
              db.execute('SELECT * from foo')
            rescue
            end
          end

          span, = @intercepted.spans
          expect(span.outcome).to eq 'failure'
        end
      end
    end
  end
end
