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
  RSpec.describe Util::PrecisionValidator do
    context 'not a float' do
      it 'returns nil' do
        expect(described_class.validate('a')).to eq nil
      end
    end

    context 'less than 0' do
      it 'returns nil' do
        expect(described_class.validate(-1)).to eq nil
      end
    end

    context 'greater than 1' do
      it 'returns nil' do
        expect(described_class.validate(2)).to eq nil
      end
    end

    context 'equal to 1' do
      it 'returns 1' do
        expect(described_class.validate(1)).to eq 1
      end
    end

    context 'equal to 0' do
      it 'returns 0' do
        expect(described_class.validate(0)).to eq 0
      end
    end

    context 'between 0 and the minimum' do
      it 'returns the minimum' do
        expect(described_class.validate(
          0.00001, precision: 4, minimum: 0.0001)
        ).to eq 0.0001
      end
    end

    context 'more digits of precision and rounded down' do
      it 'returns the rounded number' do
        expect(described_class.validate(
          0.55554, precision: 4, minimum: 0.0001)
        ).to eq 0.5555
      end
    end

    context 'more digits of precision and rounded up' do
      it 'returns the rounded number' do
        expect(described_class.validate(
          0.55555, precision: 4, minimum: 0.0001)
        ).to eq 0.5556
      end
    end
  end
end
