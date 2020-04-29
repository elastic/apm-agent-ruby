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

module ElasticAPM
  module Metrics
    RSpec.shared_examples(:span_scope_set) do
      let(:config) { Config.new }
      subject { described_class.new config }

      describe 'collect' do
        it 'moves transaction info from tags to props' do
          subject.gauge(
            :a,
            tags: { 'transaction.name': 'name', 'transaction.type': 'type' }
          )
          set, = subject.collect
          expect(set.transaction).to match(name: 'name', type: 'type')
        end

        it 'moves span info from tags to props' do
          subject.gauge(
            :a,
            tags: { 'span.type': 'type', 'span.subtype': 'subtype' }
          )
          set, = subject.collect
          expect(set.span).to match(type: 'type', subtype: 'subtype')
        end
      end
    end

    RSpec.describe TransactionSet do
      it_behaves_like :span_scope_set
    end

    RSpec.describe BreakdownSet do
      it_behaves_like :span_scope_set
    end
  end
end
