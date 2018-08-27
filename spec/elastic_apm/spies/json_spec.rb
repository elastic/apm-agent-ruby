# frozen_string_literal: true

module ElasticAPM
  RSpec.xdescribe 'Spy: JSON' do
    before do
      ElasticAPM.start disabled_spies: [], disable_send: true
    end

    after do
      ElasticAPM.stop
    end

    it 'spans #parse' do
      transaction = ElasticAPM.transaction 'T' do
        JSON.parse('[{"simply":"the best"}]')
      end.submit 200

      expect(transaction.spans.length).to be 1
      expect(transaction.spans.last.name).to eq 'JSON#parse'
    end

    it 'spans #parse!' do
      transaction = ElasticAPM.transaction 'T' do
        JSON.parse!('[{"simply":"the best"}]')
      end.submit 200

      expect(transaction.spans.length).to be 1
      expect(transaction.spans.last.name).to eq 'JSON#parse!'
    end

    it 'spans #generate' do
      transaction = ElasticAPM.transaction 'T' do
        JSON.generate([{ simply: 'the_best' }])
      end.submit 200

      expect(transaction.spans.length).to be 1
      expect(transaction.spans.last.name).to eq 'JSON#generate'
    end
  end
end
