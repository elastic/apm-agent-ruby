# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  RSpec.describe Metrics do
    let(:config) { Config.new }
    let(:callback) { ->(_) {} }
    subject { described_class.new(config, &callback) }

    describe '.new' do
      it { should be_a Metrics::Registry }
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
        it 'calls callback' do
          expect(subject.samplers.first).to receive(:collect) { { thing: 1 } }
          expect(callback).to receive(:call).with(Metricset)

          subject.collect_and_send
        end
      end

      context 'when no samples' do
        it 'calls callback' do
          expect(subject.samplers.first).to receive(:collect) { nil }
          expect(callback).to_not receive(:call)

          subject.collect_and_send
        end
      end
    end
  end
end
