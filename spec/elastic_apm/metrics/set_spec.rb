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
    RSpec.describe Set do
      let(:config) { Config.new }
      subject { described_class.new config }

      describe 'disabled?' do
        it 'can be disabled' do
          expect(subject).to_not be_disabled
          subject.disable!
          expect(subject).to be_disabled
        end
      end

      describe 'metrics' do
        it 'can have metrics' do
          subject.gauge('gauge').value = 0
          subject.counter('counter').value = 0
          subject.timer('timer').value = 0

          expect(subject.metrics.length).to be 3
        end

        it 'returns existing metrics' do
          first = subject.gauge('gauge')

          expect(subject.gauge('gauge')).to be first
          expect(subject.metrics.length).to be 1
        end

        it 'adds cardinality with tags' do
          first = subject.gauge('gauge', tags: { a: 1 })
          second = subject.gauge('gauge', tags: { a: 2 })
          expect(first).to_not be second
          expect(subject.metrics.keys).to match(
            [
              ['gauge', :a, 1],
              ['gauge', :a, 2]
            ]
          )
        end

        it 'makes noop metrics after reaching max amount' do
          expect(config.logger).to receive(:warn).with(/limit/) { true }
          stub_const('ElasticAPM::Metrics::Set::DISTINCT_LABEL_LIMIT', 3)

          4.times { |i| subject.gauge('gauge', tags: { a: i }) }

          expect(subject.metrics.length).to be 4
          expect(subject.metrics.values.last).to be NOOP
        end

        context 'with disabled metrics' do
          let(:config) { Config.new(disable_metrics: 'abc.*') }

          it 'returns noop metric for matches' do
            expect(subject.counter('abc.def')).to be Metrics::NOOP
          end
        end
      end

      describe 'collect' do
        it 'collects all metrics' do
          subject.gauge(:gauge).value = 0
          subject.counter(:counter).value = 0
          subject.timer(:timer).value = 0

          set, = subject.collect
          expect(set).to be_a Metricset
          expect(set.samples).to match(
            gauge: 0,
            counter: 0,
            timer: 0
          )
        end

        it 'skips nil metrics' do
          subject.gauge(:gauge).value = nil
          set, = subject.collect
          expect(set).to be nil
        end

        it 'splits sets by tags' do
          subject.gauge('gauge', tags: { a: 1 })
          subject.gauge('gauge', tags: { a: 2 })

          sets = subject.collect

          expect(sets.length).to be 2
        end
      end
    end
  end
end
