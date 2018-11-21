# frozen_string_literal: true

module ElasticAPM
  RSpec.describe Context do
    it 'initializes with tags and context' do
      expect(subject.tags).to eq({})
      expect(subject.custom).to eq({})
    end
  end
end
