# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  RSpec.describe TraceContext do
    describe '.new' do
      let(:transaction) { Transaction.new }

      subject { described_class.new }

      its(:version) { should be '00' }
      its(:trace_id) { should match(/.{16}/) }
      its(:id) { should match(/.{8}/) }
      its(:parent_id) { should be_nil }
      it { should be_recorded }
    end

    describe '.parse' do
      let(:header) { '00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-00' }

      subject { described_class.parse header }

      context 'with a common header' do
        it { expect { subject }.to_not raise_error }
        its(:version) { should eq '00' }
        its(:trace_id) { should eq '0af7651916cd43dd8448eb211c80319c' }
        its(:parent_id) { should eq 'b7ad6b7169203331' }
        its(:id) { should_not be_nil }
        its(:id) { should_not eq 'b7ad6b7169203331' }
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

    describe '#ensure_parent_id' do
      let(:parent_id) { nil }
      subject(:tc) { described_class.new span_id: parent_id }

      context 'parent_id set' do
        let(:parent_id) { 'b7ad6b7169203331' }
        it "doesn't change parent_id" do
          expect(tc.ensure_parent_id).to eq parent_id
          expect(tc.parent_id).to eq parent_id
        end
      end

      it 'sets and returns parent_id' do
        pid = tc.ensure_parent_id
        expect(tc.parent_id).to eq pid
      end
    end

    describe '#child' do
      let(:header) { '00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-00' }
      subject(:tc) { described_class.parse header }
      subject(:tc) do
        described_class.new span_id: 'b7ad6b7169203331', id: 'c8ad6b7169203331'
      end

      it 'sets id and parent_id' do
        child = tc.child
        expect(tc.parent_id).to eq 'b7ad6b7169203331'
        expect(tc.id).to eq 'c8ad6b7169203331'
        expect(child.parent_id).to eq 'c8ad6b7169203331'
        expect(child.id).not_to eq tc.parent_id
      end
    end

    describe '#to_header' do
      subject do
        described_class.new.tap do |tp|
          tp.trace_id = '1' * 32
          tp.id = '2' * 16
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
