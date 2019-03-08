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

      it "isn't when it has data" do
        expect(Context.new(tags: { a: 1 })).to_not be_empty
        expect(Context.new(custom: { a: 1 })).to_not be_empty
        expect(Context.new(user: { a: 1 })).to_not be_empty
        expect(Context.new.tap { |c| c.request = 1 }).to_not be_empty
        expect(Context.new.tap { |c| c.response = 1 }).to_not be_empty
      end
    end
  end
end
