# frozen_string_literal: true

require 'spec_helper'
require 'elastic_apm/injectors/sequel'
require 'sequel'

module ElasticAPM
  RSpec.describe Injectors::SequelInjector do
    it 'registers' do
      registration =
        Injectors.require_hooks['sequel'] || # when missing
        Injectors.installed['Sequel']        # with present

      expect(registration.injector).to be_a described_class
    end

    it 'spans calls' do
      db = ::Sequel.sqlite # in-memory

      db.create_table :users do
        primary_key :id
        String :name
      end

      db[:users].count # warm up

      ElasticAPM.start Config.new(enabled_injectors: %w[sequel])

      transaction = ElasticAPM.transaction 'Sequel test' do
        db[:users].count
      end.submit 200

      ElasticAPM.stop

      pp Util::Inspector.new.transaction transaction

      expect(transaction.spans.length).to be 1

      span = transaction.spans.first
      expect(span.name).to eq 'SELECT FROM `users`'
    end
  end
end
