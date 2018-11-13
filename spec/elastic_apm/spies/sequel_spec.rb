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

      ElasticAPM.start

      ElasticAPM.with_transaction 'Sequel test' do
        db[:users].count
      end

      ElasticAPM.stop

      span, = @intercepted.spans

      expect(span.name).to eq 'SELECT FROM users'
      expect(span.context.db.statement)
        .to eq "SELECT count(*) AS 'count' FROM `users` LIMIT 1"
    end
  end
end
