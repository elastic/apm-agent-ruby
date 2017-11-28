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

    it 'spans #parse' do
      ElasticAPM.start Config.new(enabled_injectors: %w[json])

      transaction = ElasticAPM.transaction 'T' do
        JSON.parse('[{"simply":"the best"}]')
      end.submit 200

      expect(transaction.spans.length).to be 1
      expect(transaction.spans.last.name).to eq 'JSON#parse'

      ElasticAPM.stop
    end

    it 'spans #parse!' do
      ElasticAPM.start Config.new(enabled_injectors: %w[json])

      transaction = ElasticAPM.transaction 'T' do
        JSON.parse!('[{"simply":"the best"}]')
      end.submit 200

      expect(transaction.spans.length).to be 1
      expect(transaction.spans.last.name).to eq 'JSON#parse!'

      ElasticAPM.stop
    end

    it 'spans #generate' do
      ElasticAPM.start Config.new(enabled_injectors: %w[json])

      transaction = ElasticAPM.transaction 'T' do
        JSON.generate([{ simply: 'the_best' }])
      end.submit 200

      expect(transaction.spans.length).to be 1
      expect(transaction.spans.last.name).to eq 'JSON#generate'

      ElasticAPM.stop
    end
  end
end
