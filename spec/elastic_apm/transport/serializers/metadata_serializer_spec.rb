# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  module Transport
    module Serializers
      RSpec.describe MetadataSerializer do
        subject { described_class.new }
        let(:result) { subject.build(metadata) }
        before { allow(ElasticAPM).to receive(:config).and_return(config) }

        describe '#build' do
          let(:config) { Config.new }
          let(:metadata) { Metadata.new config }

          it 'is a bunch of hashes and no labels' do
            expect(result[:metadata]).to be_a Hash
            expect(result[:metadata][:service]).to be_a Hash
            expect(result[:metadata][:process]).to be_a Hash
            expect(result[:metadata][:system]).to be_a Hash
            expect(result[:metadata][:labels]).to be_nil
          end

          context 'when there are global_labels' do
            let(:config) { Config.new(global_labels: { apples: 'oranges' }) }
            let(:metadata) { Metadata.new config }

            it 'is a bunch of hashes' do
              expect(result[:metadata]).to be_a Hash
              expect(result[:metadata][:service]).to be_a Hash
              expect(result[:metadata][:process]).to be_a Hash
              expect(result[:metadata][:system]).to be_a Hash
              expect(result[:metadata][:labels]).to be_a Hash
            end
          end
        end
      end
    end
  end
end
