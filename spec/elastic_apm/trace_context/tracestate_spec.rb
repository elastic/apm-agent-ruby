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
    describe '.parse' do
      subject { described_class.parse(header) }

      context 'without an es section' do
        let(:header) { "a=b,c=d\ne=f" }

        it 'splits into individual entries by key' do
          expect(subject.entries.keys).to eq %w[a c e]
          expect(subject.entries.count).to be 3
        end
      end
    end

    describe '#to_header' do
      subject { described_class.parse(header) }

      context 'with multiple sections' do
        let(:header) { "a=b,c=d\ne=f" }
        its(:to_header) { is_expected.to eq 'a=b,c=d,e=f' }
      end
    end

    context 'with an es field' do
      subject { described_class.parse(header) }

      let(:header) { "es=s:1;b:2,othervendor=na" }

      it 'parses es field' do
        expect(subject.entries['es'].value).to eq('s:1.0')
        expect(subject.entries['othervendor'].value).to eq 'na'
      end

      context 'with bad values' do
        [
          ['es=xyz', nil],
          ['es=s:foo', nil],
          ['es=s:1.5', nil]
        ].each do |(input, expectation)|
          describe input do
            let(:header) { input }
            it 'is nil' do
              expect(subject.entries['es'].to_s).to be expectation
            end
          end
        end
      end
    end

    context 'sample_rate' do
      it 'is nil when not set' do
        state = described_class.parse('a=b')
        expect(state.sample_rate).to be nil
      end

      it 'parses good values' do
        state = described_class.parse('es=s:0.5')
        expect(state.sample_rate).to eq 0.5
        expect(state.to_header).to eq 'es=s:0.5'
      end

      it 'ensures max 4 digits of precision' do
        state = described_class.new
        state.sample_rate = 0.55554
        expect(state.to_header).to eq('es=s:0.5555')
      end
    end
  end
end
