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
      expect(span.context.db.statement)
        .to eq "SELECT count(*) AS 'count' FROM `users` LIMIT 1"

      destination = span.context.destination
      expect(destination.name).to eq 'sqlite'
      expect(destination.resource).to eq 'sqlite'
      expect(destination.type).to eq 'db'
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
  end
end
