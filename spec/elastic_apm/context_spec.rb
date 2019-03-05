# frozen_string_literal: true

module ElasticAPM
  RSpec.describe Context do
    it 'initializes with tags and context' do
      expect(subject.tags).to eq({})
      expect(subject.custom).to eq({})
    end

    describe '#empty?' do
      it 'is when new' do
        expect(Context.new).to be_empty
      end
    end
  end
end
