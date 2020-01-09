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

      with_agent(use_experimental_sql_parser: true) do
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
  end
end
