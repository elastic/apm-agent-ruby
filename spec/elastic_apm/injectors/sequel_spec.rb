# frozen_string_literal: true

require 'spec_helper'
require 'sequel'

module ElasticAPM
  RSpec.describe 'Injectors::SequelInjector', :with_fake_server do
    it 'spans calls' do
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

      transaction = ElasticAPM.transaction 'Sequel test' do
        db[:users].count
      end.submit 200

      ElasticAPM.stop

      expect(transaction.spans.length).to be 1

      span = transaction.spans.first
      expect(span.name).to eq 'SELECT FROM `users`'
      expect(span.context.statement)
        .to eq "SELECT count(*) AS 'count' FROM `users` LIMIT 1"
    end
  end
end
