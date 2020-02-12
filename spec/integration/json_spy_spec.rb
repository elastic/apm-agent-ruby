# frozen_string_literal: true

module ElasticAPM
  RSpec.describe 'Spy: JSON', :intercept do
    before do
      intercept!
      ElasticAPM.start disable_instrumentations: []
    end

    after do
      ElasticAPM.stop
    end

    it 'spans #parse' do
      with_agent do
        ElasticAPM.with_transaction do
          JSON.parse('[{"simply":"the best"}]')
        end
      end

      expect(@intercepted.spans.length).to be 1
      expect(@intercepted.spans.last.name).to eq 'JSON#parse'
    end

    it 'spans #parse!' do
      with_agent do
        ElasticAPM.with_transaction do
          JSON.parse!('[{"simply":"the best"}]')
        end
      end

      expect(@intercepted.spans.length).to be 1
      expect(@intercepted.spans.last.name).to eq 'JSON#parse!'
    end

    it 'spans #generate' do
      with_agent do
        ElasticAPM.with_transaction do
          JSON.generate([{ simply: 'the_best' }])
        end
      end

      expect(@intercepted.spans.length).to be 1
      expect(@intercepted.spans.last.name).to eq 'JSON#generate'
    end
  end
end
