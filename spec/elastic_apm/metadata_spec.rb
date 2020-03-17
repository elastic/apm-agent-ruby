# frozen_string_literal: true

require 'logger'

require 'elastic_apm/config'
require 'elastic_apm/util'
require 'elastic_apm/metadata'

module ElasticAPM
  RSpec.describe Metadata do
    let(:config) { Config.new(global_labels: { apples: 'oranges' }) }
    subject { described_class.new(config) }

    describe '#labels' do
      it 'accesses the config\'s labels' do
        expect(subject.labels).to eq(apples: 'oranges')
      end
    end
  end
end
