# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  module Transport
    module Serializers
      RSpec.describe MetadataSerializer do
        subject { described_class.new Config.new }

        describe '#build' do
          let(:metadata) { Metadata.new Config.new }
          let(:result) { subject.build(metadata) }

          it 'is a bunch of hashes' do
            expect(result[:metadata]).to be_a Hash
            expect(result[:metadata][:service]).to be_a Hash
            expect(result[:metadata][:process]).to be_a Hash
            expect(result[:metadata][:system]).to be_a Hash
          end
        end
      end
    end
  end
end
