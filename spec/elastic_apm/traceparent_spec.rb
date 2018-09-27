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
        it { expect { subject }.to_not raise_error }
        its(:version) { should eq '00' }
        its(:trace_id) { should eq '0af7651916cd43dd8448eb211c80319c' }
        its(:span_id) { should eq 'b7ad6b7169203331' }
        its(:flags) { should eq '00000000' }
      end

      context 'with a blank header' do
        let(:header) { '' }
        it do
          expect { subject }
            .to raise_error(Traceparent::InvalidTraceparentHeader)
        end
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

      context 'with unknown version' do
        let(:header) do
          '01-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-03'
        end
        it do
          expect { subject }
            .to raise_error(Traceparent::InvalidTraceparentHeader)
        end
      end

      context 'with non-hex trace id' do
        let(:header) do
          '00-Ggf7651916cd43dd8448eb211c80319c-b7ad6b7169203331-03'
        end
        it do
          expect { subject }
            .to raise_error(Traceparent::InvalidTraceparentHeader)
        end
      end

      context 'with unknown version' do
        let(:header) do
          '00-0af7651916cd43dd8448eb211c80319c-XXad6b7169203331-03'
        end
        it do
          expect { subject }
            .to raise_error(Traceparent::InvalidTraceparentHeader)
        end
      end
    end

    describe '#to_s' do
      subject do
        described_class.new.tap do |tp|
          tp.trace_id = '1' * 32
          tp.span_id = '2' * 16
          tp.flags = '00000011'
        end
      end

      its(:to_s) do
        should match(/00-11111111111111111111111111111111-2222222222222222-03/)
      end
    end

    describe '#flags' do
      context 'with flags as props' do
        subject do
          described_class.new.tap do |tp|
            tp.recorded = true
            tp.requested = false
          end
        end
        its(:flags) { should eq '00000010' }
      end
    end
  end
end
