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

require 'elastic_apm/sql/tokenizer'
require 'json'

module ElasticAPM
  module Sql
    RSpec.describe Tokenizer do
      describe 'examples:' do
        file_contents = File.read('spec/fixtures/sql_token_examples.json', :encoding => 'utf-8')
        examples =
          JSON.parse(file_contents)

        examples.each do |info|
          desc = info['name']
          desc += ": #{info['comment']}" if info['comment']
          it desc do
            scanner = described_class.new(info['input'])

            info.fetch('tokens', []).each do |expected|
              expect(scanner.scan).to be true
              expect(
                'kind' => scanner.token.to_s,
                'text' => scanner.text
              ).to eq(expected), info['input']
            end
          end
        end
      end

      describe '#scan' do
        it 'is true until end of string' do
          scanner = described_class.new('a b c')
          expect(scanner.scan).to be true
          expect(scanner.scan).to be true
          expect(scanner.scan).to be true
          expect(scanner.scan).to be false
        end
      end
    end
  end
end
