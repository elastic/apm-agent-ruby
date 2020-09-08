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
  RSpec.describe Metrics do
    let(:config) { Config.new }
    let(:callback) { ->(_) {} }
    subject { described_class.new(config, &callback) }

    describe 'life cycle' do
      describe '#start' do
        before { subject.start }
        it { should be_running }
      end

      describe '#stop' do
        it 'stops the collector' do
          subject.start
          subject.stop
          expect(subject).to_not be_running
        end
      end

      describe 'stop and start again' do
        before do
          subject.start
          subject.stop
        end
        after { subject.stop }

        it 'restarts collecting metrics' do
          subject.start
          expect(subject.instance_variable_get(:@timer_task)).to be_running
        end
      end

      context 'when disabled' do
        let(:config) { Config.new metrics_interval: '0s' }

        it "doesn't start" do
          subject.start
          expect(subject).to_not be_running
          subject.stop
          expect(subject).to_not be_running
        end
      end
    end

    describe '.new' do
      it { should be_a Metrics::Registry }
    end

    describe '.collect' do
      before { subject.start }
      after { subject.stop }

      it 'samples all samplers' do
        subject.sets.each_value do |sampler|
          expect(sampler).to receive(:collect).at_least(:once)
        end
        subject.collect
      end
    end

    describe '.collect_and_send' do
      before { subject.start }
      after { subject.stop }

      context 'when samples' do
        it 'calls callback' do
          subject.collect_and_send # disable on unsupported jruby
          next unless subject.sets.values.select { |s| s.metrics.any? }.any?

          expect(callback).to receive(:call).with(Metricset).at_least(1)
          subject.collect_and_send
        end
      end

      context 'when no samples' do
        it 'calls callback' do
          subject.sets.each_value do |sampler|
            expect(sampler).to receive(:collect).at_least(:once) { nil }
          end
          expect(callback).to_not receive(:call)

          subject.collect_and_send
        end
      end

      context 'when recording is false' do
        let(:config) { Config.new(recording: false) }
        it 'does not collect metrics' do
          expect(subject).to_not receive(:collect)
          subject.collect_and_send
        end
      end
    end

    xcontext 'thread safety stress test', :mock_intake do
      it 'handles multiple threads reporting and collecting at the same time' do
        thread_count = 1_000

        names = Array.new(5).map do
          SecureRandom.hex(5)
        end

        with_agent(metrics_interval: '100ms') do
          metrics = ElasticAPM.agent.metrics

          Array.new(thread_count).map do
            Thread.new do
              metrics.get(:breakdown).counter('a').inc!
              metrics.get(:breakdown).counter('b').inc!
              metrics.get(:breakdown).counter('c').dec!
              metrics.get(:transaction).counter(
                :a_with_tags,
                tags: { 'name': names.sample },
                reset_on_collect: true
              ).inc!
              metrics.get(:transaction).counter(
                :b_with_tags,
                tags: { 'name': names.sample },
                reset_on_collect: true
              ).inc!
              metrics.get(:transaction).counter(
                :c_with_tags,
                tags: { 'name': names.sample },
                reset_on_collect: true
              ).inc!

              sleep 0.15 # longer than metrics_interval
            end
          end.each(&:join)
        end

        samples =
          @mock_intake.metricsets.each_with_object({}) do |set, result|
            result.merge! set['samples']
          end

        expect(samples['a']['value']).to eq(thread_count)
        expect(samples['b']['value']).to eq(thread_count)
        expect(samples['c']['value']).to eq(0 - thread_count)

        expect(samples['a_with_tags']['value']).to be > 0
        expect(samples['b_with_tags']['value']).to be > 0
        expect(samples['c_with_tags']['value']).to be > 0
      end
    end

    describe '#handle_forking!' do
      before do
        subject.handle_forking!
      end
      after { subject.stop }

      it 'restarts the TimerTask' do
        expect(subject.instance_variable_get(:@timer_task)).to be_running
      end

      context 'when not collecting metrics' do
        let(:config) { Config.new(metrics_interval: 0) }

        it 'does not create a TimerTask' do
          expect(subject.instance_variable_get(:@timer_task)).to be nil
        end
      end
    end
  end
end
