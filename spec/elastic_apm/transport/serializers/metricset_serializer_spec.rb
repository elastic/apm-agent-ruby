# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  module Transport
    module Serializers
      RSpec.describe MetricsetSerializer do
        subject { described_class.new Config.new }

        describe '#build' do
          let(:set) { Metricset.new(thing: 1.0, other: 321) }
          let(:result) { subject.build(set) }

          it 'matches' do
            expect(result[:metricset]).to be_a Hash
            expect(result[:metricset][:timestamp]).to be_an Integer
            expect(result[:metricset][:samples]).to be_a Hash
            expect(result[:metricset][:samples][:thing][:value]).to eq 1.0
            expect(result[:metricset][:samples][:other][:value]).to eq 321
          end
        end
      end
    end
  end
end
