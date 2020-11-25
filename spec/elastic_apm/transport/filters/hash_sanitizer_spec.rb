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
  module Transport
    module Filters
      RSpec.describe HashSanitizer do
        let(:config) { Config.new }
        subject do
          described_class.new(key_patterns: config.sanitize_field_names)
        end

        describe '#strip_from!' do
          it 'removes secret keys from requests' do
            payload = {
              ApiKey: 'very zecret!',
              Untouched: 'very much'
            }

            subject.strip_from!(payload)

            expect(payload).to match(
              ApiKey: '[FILTERED]',
              Untouched: 'very much'
            )
          end

          it 'works on nested hashes' do
            payload = { nested: { ApiKey: '123' } }

            subject.strip_from!(payload)

            expect(payload.dig(:nested, :ApiKey)).to eq '[FILTERED]'
          end
        end

        describe '#strip_from' do
          it 'returns a recursively cloned copy' do
            obj = Object.new
            payload = { nested: { ApiKey: obj } }

            result = subject.strip_from(payload)

            expect(result).to match(nested: { ApiKey: Object })
            expect(result).to_not be payload
            expect(result.dig(:nested, :ApiKey)).to_not be obj
          end
        end
      end
    end
  end
end
