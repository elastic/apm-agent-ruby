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
#
# frozen_string_literal: true

require 'spec_helper'

if defined?(JRUBY_VERSION)
  module ElasticAPM
    module Metrics
      RSpec.describe JVMSet do
        let(:config) { Config.new }

        subject { described_class.new config }

        describe 'collect' do
          context 'when disabled' do
            it 'returns' do
              subject.disable!
              expect(subject.collect).to be nil
            end
          end

          it 'disables after three errors' do
            allow(java.lang.management.ManagementFactory).to receive(:getPlatformMXBean).and_raise(Exception)

            2.times do
              subject.collect
              expect(subject).to_not be_disabled
            end

            subject.collect
            expect(subject).to be_disabled
          end

          it 'collects a metric set and prefixes keys' do
            subject.collect
            sleep 0.2
            sets = subject.collect

            expect(sets.first.samples).to match(
              :"jvm.memory.heap.used" => Integer,
              :"jvm.memory.heap.committed" => Integer,
              :"jvm.memory.heap.max" => Integer,
              :"jvm.memory.non_heap.used" => Integer,
              :"jvm.memory.non_heap.committed" => Integer,
              :"jvm.memory.non_heap.max" => Integer,
            )
            sets[1..-1].each do |set|
              expect(set.tags).to match(name: String)
              expect(set.samples).to match(
                :"jvm.memory.heap.pool.used" => Integer,
                :"jvm.memory.heap.pool.committed" => Integer,
                :"jvm.memory.heap.pool.max" => Integer,
              )
            end
          end
        end
      end
    end
  end
end
