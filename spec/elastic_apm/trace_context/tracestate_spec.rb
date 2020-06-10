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
      it 'parses a header' do
        result = described_class.parse('a=b')
        expect(result.values).to eq(['a=b'])
      end

      it 'handles multiple values' do
        result = described_class.parse("a=b\nc=d")
        expect(result.values).to eq(['a=b', 'c=d'])
      end
    end

    describe '#to_header' do
      context 'with a single value' do
        subject { described_class.parse('a=b') }
        its(:to_header) { is_expected.to eq 'a=b' }
      end

      context 'with multiple values' do
        subject { described_class.parse("a=b\nc=d") }
        its(:to_header) { is_expected.to eq 'a=b,c=d' }
      end

      context 'with mixed' do
        subject { described_class.parse("a=b,c=d\ne=f") }
        its(:to_header) { is_expected.to eq 'a=b,c=d,e=f' }
      end
    end
  end
end
