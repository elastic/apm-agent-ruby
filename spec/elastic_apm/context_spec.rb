# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  RSpec.describe Context do
    it 'initializes with tags and context' do
      expect(subject.tags).to eq({})
      expect(subject.custom).to eq({})
    end

    describe '#to_h' do
      it 'converts to a hash' do
        expect(subject.to_h).to be_a Hash
      end
    end
  end
end
