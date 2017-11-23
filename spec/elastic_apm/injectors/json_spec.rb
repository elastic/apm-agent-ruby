# frozen_string_literal: true

require 'spec_helper'
require 'elastic_apm/injectors/json'

module ElasticAPM
  RSpec.describe Injectors::JSONInjector do
    it 'registers' do
      registration =
        Injectors.require_hooks['json'] || # when missing
        Injectors.installed['JSON']        # when present

      expect(registration.injector).to be_a described_class
    end

    it 'traces #parse' do
      ElasticAPM.start Config.new(enabled_injectors: %w[json])

      transaction = ElasticAPM.transaction 'T' do
        JSON.parse('[{"simply":"the best"}]')
      end.submit 200

      expect(transaction.traces.length).to be 1
      expect(transaction.traces.last.name).to eq 'JSON#parse'

      ElasticAPM.stop
    end

    it 'traces #parse!' do
      ElasticAPM.start Config.new(enabled_injectors: %w[json])

      transaction = ElasticAPM.transaction 'T' do
        JSON.parse!('[{"simply":"the best"}]')
      end.submit 200

      expect(transaction.traces.length).to be 1
      expect(transaction.traces.last.name).to eq 'JSON#parse!'

      ElasticAPM.stop
    end

    it 'traces #generate' do
      ElasticAPM.start Config.new(enabled_injectors: %w[json])

      transaction = ElasticAPM.transaction 'T' do
        JSON.generate([{ simply: 'the_best' }])
      end.submit 200

      expect(transaction.traces.length).to be 1
      expect(transaction.traces.last.name).to eq 'JSON#generate'

      ElasticAPM.stop
    end
  end
end
