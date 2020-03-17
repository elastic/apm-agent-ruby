# frozen_string_literal: true

require 'rspec/its'
require 'elastic_apm/util'
require 'elastic_apm/metricset'

module ElasticAPM
  RSpec.describe Metricset do
    describe 'initialize' do
      subject { described_class.new(thing: 1) }
      its(:timestamp) { should_not be nil }
      its(:samples) { should match(thing: 1) }
    end

    describe 'empty?' do
      context 'with samples' do
        subject { described_class.new thing: 1 }
        it { should_not be_empty }
      end

      context 'with no samples' do
        subject { described_class.new }
        it { should be_empty }
      end
    end
  end
end
