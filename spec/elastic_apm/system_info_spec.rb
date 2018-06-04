# frozen_string_literal: true

module ElasticAPM
  RSpec.describe SystemInfo do
    describe '#build' do
      subject { described_class.new(Config.new).build }

      it { should be_a Hash }

      it 'has values' do
        %i[hostname architecture platform].each do |key|
          expect(subject[key]).to_not be_nil
        end
      end
    end
  end
end
