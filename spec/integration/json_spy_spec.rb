# Licensed to Elasticsearch B.V. under one or more contributor
# license agreements. See the NOTICE file distributed with
# this work for additional information regarding copyright
# ownership. Elasticsearch B.V. licenses this file to you under
# the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

# frozen_string_literal: true

require 'spec_helper'

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
