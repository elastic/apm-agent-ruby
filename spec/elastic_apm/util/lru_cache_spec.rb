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
  RSpec.describe Util::LruCache do
    it 'purges when filled' do
      subject = described_class.new(2)

      subject[:a] = 1
      subject[:b] = 2
      subject[:a]
      subject[:c] = 3

      expect(subject.length).to be 2
      expect(subject.to_a).to match([[:a, 1], [:c, 3]])
    end

    it 'taks a block' do
      subject = described_class.new do |cache, key|
        cache[key] = 'missing'
      end

      expect(subject['other key']).to eq 'missing'
    end
  end
end
