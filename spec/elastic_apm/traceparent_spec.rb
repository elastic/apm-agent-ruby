# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  RSpec.describe Traceparent do
    describe '.from_transaction' do
      let(:agent) { Agent.new Config.new }
      let(:instrumenter) { Instrumenter.new agent }
      let(:transaction) { Transaction.new instrumenter }

      subject { described_class.from_transaction transaction }

      its(:version) { should be '00' }
      its(:trace_id) { should match(/.{16}/) }
      its(:span_id) { should eq transaction.id }
      it { should be_recorded }
      it { should be_requested }
    end

    describe '.parse' do
      let(:header) { '00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-00' }

      subject { described_class.parse header }

      context 'with a common header' do
        its(:version) { should eq '00' }
        its(:trace_id) { should eq '0af7651916cd43dd8448eb211c80319c' }
        its(:span_id) { should eq 'b7ad6b7169203331' }
        its(:flags) { should eq '00000000' }
      end

      context 'when neithed requested not recorded' do
        it { should_not be_recorded }
        it { should_not be_requested }
      end

      context 'when requested' do
        let(:header) do
          '00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01'
        end
        it { should be_requested }
        it { should_not be_recorded }
      end

      context 'when recorded' do
        let(:header) do
          '00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-02'
        end
        it { should_not be_requested }
        it { should be_recorded }
      end

      context 'when both requested and recorded' do
        let(:header) do
          '00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-03'
        end
        it { should be_requested }
        it { should be_recorded }
      end
    end

    describe '#valid?' do
      subject { described_class.parse header }

      context 'with unknown version' do
        let(:header) do
          '01-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-03'
        end
        it { should_not be_valid }
      end

      context 'with non-hex trace id' do
        let(:header) do
          '00-Ggf7651916cd43dd8448eb211c80319c-b7ad6b7169203331-03'
        end
        it { should_not be_valid }
      end

      context 'with unknown version' do
        let(:header) do
          '00-0af7651916cd43dd8448eb211c80319c-XXad6b7169203331-03'
        end
        it { should_not be_valid }
      end
    end
  end
end
