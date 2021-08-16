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
    RSpec.describe CpuMemSet do
      let(:config) { Config.new }
      subject { described_class.new config }

      context 'Linux' do
        before { allow(Metrics).to receive(:os) { 'linux-musl' } }

        describe 'collect' do
          it 'collects all metrics' do
            mock_proc_files(user: 0, idle: 0, utime: 0, stime: 0)

            subject # read values in init to allow delta calculation

            mock_proc_files(
              user: 400_000, idle: 600_000, utime: 100_000, stime: 100_000
            )

            set, = subject.collect

            expect(set.samples).to match(
              'system.cpu.total.norm.pct': 0.4,
              'system.memory.actual.free': 2_750_062_592,
              'system.memory.total': 4_042_711_040,
              'system.process.cpu.total.norm.pct': 0.2,
              'system.process.memory.size': 53_223_424,
              'system.process.memory.rss.bytes': 12_738_560
            )
          end

          context 'on RHEL' do
            it "doesn't explode from missing numbers" do
              mock_proc_files(
                proc_stat_format: :rhel,
                user: 0, idle: 0, utime: 0, stime: 0
              )

              subject # read values in init to allow delta calculation

              mock_proc_files(
                proc_stat_format: :rhel,
                user: 400_000, idle: 600_000, utime: 100_000, stime: 100_000
              )

              set, = subject.collect

              expect(set.samples).to match(
                'system.cpu.total.norm.pct': 0.4,
                'system.memory.actual.free': 2_750_062_592,
                'system.memory.total': 4_042_711_040,
                'system.process.cpu.total.norm.pct': 0.2,
                'system.process.memory.size': 53_223_424,
                'system.process.memory.rss.bytes': 12_738_560
              )
            end
          end

          context 'on Debian Wheezy (kernel 3.2)' do
            it 'builds MemAvailable from others' do
              mock_proc_files proc_meminfo_format: :wheezy

              set, = subject.collect

              expect(set.samples[:'system.memory.total']).to eq 4_042_711_040
              expect(set.samples[:'system.memory.actual.free'])
                .to eq 2_443_145_216
            end
          end
        end
      end

      # rubocop:disable Metrics/ParameterLists
      def mock_proc_files(
        user: 6_410_558,
        idle: 329_434_672,
        utime: 7,
        stime: 0,
        proc_stat_format: :debian,
        proc_meminfo_format: nil
      )
        {
          '/proc/stat' =>
            ["proc_stat_#{proc_stat_format}", { user: user, idle: idle }],
          '/proc/self/stat' =>
            ['proc_self_stat', { utime: utime, stime: stime }],
          '/proc/meminfo' =>
            [
              "proc_meminfo#{proc_meminfo_format && "_#{proc_meminfo_format}"}",
              {}
            ]
        }.each do |file, (fixture, updates)|
          allow(IO).to receive(:readlines).with(file) do
            text = File.read("spec/fixtures/#{fixture}")
            updates.each { |key, val| text.gsub!("{#{key}}", val.to_s) }
            text.split("\n")
          end
        end
      end
      # rubocop:enable Metrics/ParameterLists
    end
  end
end
