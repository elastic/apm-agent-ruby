# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  RSpec.describe Traceparent do
    let(:header) { '00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-00' }

    subject { described_class.new header }

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
      let(:header) { '00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01' }
      it { should be_requested }
      it { should_not be_recorded }
    end

    context 'when recorded' do
      let(:header) { '00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-02' }
      it { should_not be_requested }
      it { should be_recorded }
    end

    context 'when both requested and recorded' do
      let(:header) { '00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-03' }
      it { should be_requested }
      it { should be_recorded }
    end
  end
end
