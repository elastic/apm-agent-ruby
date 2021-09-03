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
  module Metrics
    RSpec.describe Metric do
      context 'with an initial value' do
        subject { described_class.new(:key, initial_value: 666) }

        its(:value) { is_expected.to eq 666 }

        describe 'reset!' do
          it 'resets to initial value' do
            subject.value = 123
            expect(subject.value).to eq 123
            subject.reset!
            expect(subject.value).to eq 666
          end
        end

        describe 'tags?' do
          it 'is false when nil' do
            expect(described_class.new(:key).tags?).to be false
          end

          it 'is false when empty' do
            expect(described_class.new(:key, tags: {}).tags?).to be false
          end

          it 'is true when present' do
            expect(described_class.new(:key, tags: { a: 1 }).tags?).to be true
          end
        end

        describe 'collect' do
          subject do
            described_class.new(
              :key,
              initial_value: 666, reset_on_collect: true
            )
          end

          it 'resets value if told to' do
            expect(subject.collect).to eq 666
            subject.value = 321
            expect(subject.collect).to eq 321
            expect(subject.collect).to eq 666
          end

          it 'skips 0 values' do
            subject.value = 0
            expect(subject.collect).to be nil
          end

          it 'skips NaN values' do
            subject.value = 0.0/0
            expect(subject.collect).to be nil
          end
        end
      end
    end

    RSpec.describe Counter do
      subject { described_class.new(:key, initial_value: 666) }

      it 'increments' do
        subject.inc!
        expect(subject.value).to eq 667
      end

      it 'decrements' do
        subject.dec!
        expect(subject.value).to eq 665
      end
    end

    RSpec.describe Timer do
      subject { described_class.new(:key) }

      it 'updates' do
        subject.update(10, delta: 5)
        expect(subject.value).to eq 10
        expect(subject.count).to eq 5
      end

      it 'resets' do
        subject.update(10, delta: 5)
        subject.reset!
        expect(subject.value).to eq 0
        expect(subject.count).to eq 0
      end
    end
  end
end
