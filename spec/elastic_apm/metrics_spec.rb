# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  RSpec.describe Metrics do
    let(:config) { Config.new }
    let(:agent) { double('agent', enqueue: true) }
    subject { described_class.new(config, agent) }

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
      it { should be_a Metrics::Collector }
    end

    describe '.collect' do
      it 'samples all samplers' do
        subject.samplers.each do |sampler|
          expect(sampler).to receive(:collect)
        end
        subject.collect
      end
    end

    describe '.collect_and_send' do
      context 'when samples' do
        it 'calls enqueue on the agent' do
          expect(subject.samplers.first).to receive(:collect) { { thing: 1 } }
          expect(agent).to receive(:enqueue).with(Metricset)

          subject.collect_and_send
        end
      end

      context 'when no samples' do
        it 'does not call enqueue on the agent' do
          subject.samplers.each do |sampler|
            expect(sampler).to receive(:collect) { nil }
          end
          expect(agent).to_not receive(:enqueue)

          subject.collect_and_send
        end
      end
    end
  end
end
