# frozen_string_literal: true

module ElasticAPM
  RSpec.describe Context do
    it 'initializes with labels and context' do
      expect(subject.labels).to eq({})
      expect(subject.custom).to eq({})
    end

    describe '#empty?' do
      it 'is when new' do
        expect(Context.new).to be_empty
      end

      it "isn't when it has data" do
        expect(Context.new(labels: { a: 1 })).to_not be_empty
        expect(Context.new(custom: { a: 1 })).to_not be_empty
        expect(Context.new(user: { a: 1 })).to_not be_empty
        expect(Context.new.tap { |c| c.request = 1 }).to_not be_empty
        expect(Context.new.tap { |c| c.response = 1 }).to_not be_empty
      end
    end

    describe 'service' do
      before do
        subject.set_service(framework_name: 'Grape',
                            framework_version: '1.2')
      end

      it 'sets the service' do
        expect(subject.service.framework.name).to eq('Grape')
        expect(subject.service.framework.version).to eq('1.2')
      end
    end
  end
end
