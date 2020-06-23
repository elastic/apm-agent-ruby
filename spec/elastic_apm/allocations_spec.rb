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

    describe Methods do
      class AllocationsTestObj
        include Allocations::Methods

        def initialize(parent: nil)
          @parent = parent
        end

        def start
          @parent&.child_started
          allocations.start
        end

        def stop
          @parent&.child_stopped
          allocations.stop
        end

        def child_started
        end

        def child_stopped
        end
      end

      subject { AllocationsTestObj.new }

      it { is_expected.to respond_to :allocations }

      it "tracks total allocations" do
        subject.start
        Object.new
        subject.stop
        expect(subject.allocations.count).to be 1
      end

      it "tracks self allocations" do
        subject.start
        Object.new
        subject.stop
        expect(subject.allocations.self_count).to be 1
      end

      it "doesn't do any allocations itself" do
        subject.start
        subject.stop
        expect(subject.allocations.count).to be 0
      end

      it "captures a snapshot at start" do
        subject.start
        subject.stop
        expect(subject.allocations.start).to_not be_nil
      end

      context 'nested' do
        it 'tracks self time' do
          subject.start

          Object.new

          nested = AllocationsTestObj.new(parent: subject)
          nested.start
          Object.new
          nested.stop

          Object.new

          subject.stop

          expect(nested.allocations.count).to be 1
          expect(nested.allocations.self_count).to be 1
          expect(subject.allocations.count).to be 8
          expect(subject.allocations.self_count).to be 8
        end
      end
    end
  end
end
