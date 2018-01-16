# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  RSpec.describe Stacktrace::LineCache do
    it 'can get and set values' do
      subject.set(
        'something.rb',
        [1, 2, 3],
        ['LINE 1', 'LINE 2', 'LINE 3']
      )

      expect(subject.get('something.rb', [1, 2, 3])).to eq(
        ['LINE 1', 'LINE 2', 'LINE 3']
      )
    end

    it 'purges after max size is reached' do
      subject = described_class.new(2)
      subject.set(:a, 1)
      subject.set(:b, 2)
      subject.get(:a)
      subject.set(:c, 3)

      expect(subject.length).to be 2
      expect(subject.to_a).to eq([[[:a], 1], [[:c], 3]])
    end

    it 'is a singleton' do
      described_class.set(:a, 1)
      expect(described_class.get(:a)).to eq(1)
    end
  end
end
