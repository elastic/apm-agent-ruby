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

require 'elastic_apm/sql/signature'
require 'json'

module ElasticAPM
  module Sql
    RSpec.describe Signature do
      describe 'examples:' do
        examples =
          JSON.parse(File.read('spec/fixtures/sql_signature_examples.json'))

        examples.each_with_index.each do |info, i|
          desc = "0#{i}"[-2..-1] + ': '

          if info['comment']
            desc += info['comment']
          else
            desc += info['input'][0...60].inspect
            desc += ' => '
            desc += info['output'].inspect
          end

          it(desc) do
            expect(described_class.parse(info['input'])).to eq(info['output'])
          end
        end
      end

      describe 'invalid UTF-8 byte sequences' do
        context 'when the string contains an invalid byte sequence' do
          it 'encodes to UTF-8 and replaces invalid byte sequences' do
            string = "INSERT INTO \"checksums\" (\"checksum\") VALUES ( \",&\xB4kh\")"
            expect(described_class.parse(string)).to eq("INSERT INTO checksums")
          end
        end
        context 'when the entire string is an invalid byte sequence' do
          it 'encodes to UTF-8 and replaces invalid byte sequences' do
            string = "\xB4"
            expect(described_class.parse(string)).to eq("�")
          end
        end
      end
    end
  end
end
