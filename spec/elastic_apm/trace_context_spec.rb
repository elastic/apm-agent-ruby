# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  RSpec.describe TraceContext do
    describe '.for_transaction' do
      let(:transaction) { Transaction.new }

      subject { described_class.for_transaction transaction }

      its(:version) { should be '00' }
      its(:trace_id) { should match(/.{16}/) }
      its(:span_id) { should be transaction.id }
      it { should be_recorded }
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
            .to raise_error(TraceContext::InvalidTraceparentHeader)
        end
      end

      context 'when recorded' do
        let(:header) do
          '00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01'
        end
        it { should be_recorded }
      end

      context 'with unknown version' do
        let(:header) do
          '01-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-03'
        end
        it do
          expect { subject }
            .to raise_error(TraceContext::InvalidTraceparentHeader)
        end
      end

      context 'with non-hex trace id' do
        let(:header) do
          '00-Ggf7651916cd43dd8448eb211c80319c-b7ad6b7169203331-03'
        end
        it do
          expect { subject }
            .to raise_error(TraceContext::InvalidTraceparentHeader)
        end
      end

      context 'with non-hex span id' do
        let(:header) do
          '00-0af7651916cd43dd8448eb211c80319c-XXad6b7169203331-03'
        end
        it do
          expect { subject }
            .to raise_error(TraceContext::InvalidTraceparentHeader)
        end
      end
    end

    describe '#to_header' do
      subject do
        described_class.new.tap do |tp|
          tp.trace_id = '1' * 32
          tp.span_id = '2' * 16
          tp.flags = '00000011'
        end
      end

      its(:to_header) do
        should match('00-11111111111111111111111111111111-2222222222222222-01')
      end
    end

    describe '#flags' do
      context 'with flags as props' do
        subject do
          described_class.new.tap do |tp|
            tp.recorded = true
          end
        end
        its(:flags) { should eq '00000001' }
      end
    end
  end
end
