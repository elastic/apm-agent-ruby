# frozen_string_literal: true

module ElasticAPM
  module Metrics
    RSpec.describe VM do
      let(:config) { Config.new }

      subject { described_class.new config }

      describe 'collect' do
        it 'collects a metric set and prefixes keys' do
          expect(subject.collect).to match(
            'ruby.gc.count': Integer,
            'ruby.heap.slots.live': Integer,
            'ruby.heap.slots.free': Integer,
            'ruby.heap.allocations.total': Integer,
            'ruby.threads': Integer
          )
        end

        context 'with profiler enabled' do
          around do |example|
            GC::Profiler.enable
            example.run
            GC::Profiler.disable
          end

          it 'adds time spent' do
            expect(subject.collect).to have_key(:'ruby.gc.time')
          end
        end
      end
    end
  end
end
