# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  module Metrics
    RSpec.describe Metric do
      context 'with an initial value' do
        subject { described_class.new(:key, initial_value: 666) }

        its(:value) { is_expected.to eq 666 }

        it 'can reset' do
          subject.value = 123
          expect(subject.value).to eq 123
          subject.reset!
          expect(subject.value).to eq 666
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
        subject.update(10, count: 5)
        expect(subject.value).to eq 10
        expect(subject.count).to eq 5
      end

      it 'resets' do
        subject.update(10, count: 5)
        subject.reset!
        expect(subject.value).to eq 0
        expect(subject.count).to eq 0
      end
    end
  end
end
