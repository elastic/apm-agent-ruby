require 'spec_helper'

module ElasticAPM
  RSpec.describe Allocations do
    context 'mri', if: !RSpec::Support::Ruby.jruby? do
      describe ".count" do
        subject { described_class }

        it 'is enabled' do
          expect(described_class::ENABLED).to be true
        end

        it { is_expected.to respond_to :count }

        it 'is the total amount of allocated objects' do
          count = ElasticAPM::Allocations.count
          expect(count).to be_a Integer
        end

        it 'goes up over time' do
          expect(ElasticAPM::Allocations.count).to be < ElasticAPM::Allocations.count
        end
      end
    end

    context 'mri', if: RSpec::Support::Ruby.jruby? do
      it 'is not enabled' do
        expect(described_class::ENABLED).to be false
      end

      describe ".count" do
        its(:count) { is_expected.to be nil }
      end
    end
  end
end
