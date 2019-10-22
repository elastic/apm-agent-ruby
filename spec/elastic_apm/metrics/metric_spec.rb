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
