# frozen_string_literal: true

module ElasticAPM
  module Metrics
    RSpec.describe VM do
      let(:config) { Config.new }

      before(:all) { GC::Profiler.enable }

      subject { described_class.new config }

      describe 'collect' do
        it 'collects a metric set and prefixes keys' do
          expect(subject.collect).to match(
            'ruby.gc.count': Integer,
            'ruby.gc.time': Float,
            'ruby.heap.live': Integer,
            'ruby.heap.free': Integer,
            'ruby.allocations.total': Integer,
            'ruby.threads': Integer
          )
        end
      end
    end
  end
end
