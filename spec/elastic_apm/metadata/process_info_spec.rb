# frozen_string_literal: true

require 'logger'
require 'elastic_apm/config'
require 'elastic_apm/metadata/process_info'

module ElasticAPM
  RSpec.describe Metadata::ProcessInfo do
    describe '#initialize' do
      subject { described_class.new(Config.new) }

      it 'knows about the process' do
        expect(subject.argv).to be_a Array
        expect(subject.pid).to be_a Integer
        expect(subject.title).to match(/rspec/)
      end
    end
  end
end
