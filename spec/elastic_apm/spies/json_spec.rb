# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  RSpec.describe 'Spy: JSON', :with_fake_server do
    it 'spans #parse' do
      ElasticAPM.start disabled_spies: []

      transaction = ElasticAPM.transaction 'T' do
        JSON.parse('[{"simply":"the best"}]')
      end.submit 200

      expect(transaction.spans.length).to be 1
      expect(transaction.spans.last.name).to eq 'JSON#parse'

      ElasticAPM.stop
    end

    it 'spans #parse!' do
      ElasticAPM.start disabled_spies: []

      transaction = ElasticAPM.transaction 'T' do
        JSON.parse!('[{"simply":"the best"}]')
      end.submit 200

      expect(transaction.spans.length).to be 1
      expect(transaction.spans.last.name).to eq 'JSON#parse!'

      ElasticAPM.stop
    end

    it 'spans #generate' do
      ElasticAPM.start disabled_spies: []

      transaction = ElasticAPM.transaction 'T' do
        JSON.generate([{ simply: 'the_best' }])
      end.submit 200

      expect(transaction.spans.length).to be 1
      expect(transaction.spans.last.name).to eq 'JSON#generate'

      ElasticAPM.stop
    end
  end
end
