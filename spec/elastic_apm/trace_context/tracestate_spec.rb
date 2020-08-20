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
  RSpec.describe TraceContext::Tracestate do
    subject { described_class.parse(header) }

    describe '.parse' do
      context 'without an es section' do
        let(:header) { "a=b,c=d\ne=f" }

        it 'splits into individual entries by key' do
          expect(subject.entries.keys).to eq %w[a c e]
          expect(subject.entries.values.map(&:class).uniq)
            .to eq [TraceContext::Tracestate::Entry]
        end
      end
    end

    describe '#to_header' do
      context 'with multiple sections' do
        let(:header) { "a=b,c=d\ne=f" }
        its(:to_header) { is_expected.to eq 'a=b,c=d,e=f' }
      end
    end

    context 'with an es field' do
      let(:header) { "es=a:1;b:2,othervendor=na" }

      it 'parses es field into hash' do
        expect(subject.entries['es'].values).to eq('a' => '1', 'b' => '2')
        expect(subject.entries['othervendor'].values).to be nil
      end

      it 'can be modified' do
        subject.entries['es'].set(:a, 0.1)
        expect(subject.entries['es'].values).to eq('a' => '0.1', 'b' => '2')
        expect(subject.to_header).to eq('es=a:0.1;b:2,othervendor=na')
      end
    end
  end
end
