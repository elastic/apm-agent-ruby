# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  RSpec.describe Metadata do
    let(:config) { Config.new(global_labels: { apples: 'oranges' }) }
    before { allow(ElasticAPM).to receive(:config).and_return(config) }
    subject { described_class.new }

    describe '#labels' do
      it 'accesses the config\'s labels' do
        expect(subject.labels).to eq(apples: 'oranges')
      end
    end
  end
end
