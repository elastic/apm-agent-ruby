# frozen_string_literal: true

module ElasticAPM
  RSpec.describe Util::LruCache do
    it 'purges when filled' do
      subject = described_class.new(2)

      subject[:a] = 1
      subject[:b] = 2
      subject[:a]
      subject[:c] = 3

      expect(subject.length).to be 2
      expect(subject.to_a).to match([[:a, 1], [:c, 3]])
    end

    it 'taks a block' do
      subject = described_class.new do |cache, key|
        cache[key] = 'missing'
      end

      expect(subject['other key']).to eq 'missing'
    end
  end
end
