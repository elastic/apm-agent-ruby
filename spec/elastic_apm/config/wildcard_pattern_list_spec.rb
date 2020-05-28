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
  class Config
    RSpec.describe WildcardPatternList::WildcardPattern do
      subject { described_class.new(pattern) }

      [
        ['a*c', 'abc', true],
        ['a*d', 'abcd', true],
        ['a*c', 'abcd', false],
        ['*d', 'abcd', true],
        ['ab*', 'abcd', true],
        ['a.cd', 'abcd', false],
        ['a?cd', 'abcd', false],
        ['AbC', 'abc', true]
      ].each do |(pattern, string, expectation)|
        context pattern do
          let(:pattern) { pattern }

          it "#{expectation ? 'matches' : "doesn't match"} #{string}" do
            expect(subject.match?(string)).to be(expectation)
          end
        end
      end
    end

    RSpec.describe WildcardPatternList do
      let(:patterns) { 'foor.*,*.bar' }

      subject { described_class.new.call patterns }

      it { is_expected.to be_a Array }

      it 'converts to patterns' do
        expect(subject.length).to be 2

        first, last = subject
        expect(first).to be_a WildcardPatternList::WildcardPattern
        expect(last).to be_a WildcardPatternList::WildcardPattern
      end
    end
  end
end
