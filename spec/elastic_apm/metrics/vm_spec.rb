# frozen_string_literal: true

module ElasticAPM
  module Metrics
    RSpec.describe VM do
      let(:config) { Config.new }

      before { GC::Profiler.enable }

      subject { described_class.new config }

      describe 'sample' do
        it 'gets a sample of relevant info' do
          sample = subject.sample
          expect(sample).to be_a(Hash)
        end
      end

      describe 'collect' do
        it 'collects a metric set and prefixes keys' do
          subject.collect.each_key do |key|
            expect(key).to start_with('runtime.ruby.')
          end
        end
      end
    end
  end
end
