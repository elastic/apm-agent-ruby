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
    RSpec.describe VMSet do
      let(:config) { Config.new }

      subject { described_class.new config }

      describe 'collect' do
        context 'when disabled' do
          it 'returns' do
            subject.disable!
            expect(subject.collect).to be nil
          end
        end

        context 'when failing' do
          it 'disables and returns nil' do
            allow(GC).to receive(:stat).and_raise(TypeError)

            expect(subject.collect).to be nil
            expect(subject).to be_disabled
          end
        end

        context 'mri', unless: RSpec::Support::Ruby.jruby? do
          it 'collects a metric set and prefixes keys' do
            set, = subject.collect

            expect(set.samples).to match(
              'ruby.gc.count': Integer,
              'ruby.heap.slots.live': Integer,
              'ruby.heap.slots.free': Integer,
              'ruby.heap.allocations.total': Integer,
              'ruby.threads': Integer
            )
          end

          context 'with profiler enabled' do
            around do |example|
              GC::Profiler.enable
              example.run
              GC::Profiler.disable
            end

            it 'adds time spent' do
              set, = subject.collect
              expect(set.samples).to have_key(:'ruby.gc.time')
            end
          end
        end

        context 'jruby', if: RSpec::Support::Ruby.jruby? do
          it 'collects a metric set and prefixes keys' do
            subject.collect # disable on strict plaforms
            next if subject.disabled?

            set, = subject.collect

            expect(set.samples).to match(
              'ruby.gc.count': Integer,
              'ruby.threads': Integer
            )
          end
        end
      end
    end
  end
end
