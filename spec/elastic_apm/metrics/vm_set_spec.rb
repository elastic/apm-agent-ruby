# frozen_string_literal: true

module ElasticAPM
  module Metrics
    RSpec.describe VMSet do
      let(:config) { Config.new }

      subject { described_class.new config }

      describe 'collect' do
        context 'when disabled' do
          it 'returns' do
            subject.disable!
            expect(subject.collect).to be nil
          end
        end

        context 'when failing' do
          it 'disables and returns nil' do
            allow(GC).to receive(:stat).and_raise(TypeError)

            expect(subject.collect).to be nil
            expect(subject).to be_disabled
          end
        end

        context 'mri', unless: RSpec::Support::Ruby.jruby? do
          it 'collects a metric set and prefixes keys' do
            set, = subject.collect

            expect(set.samples).to match(
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
              set, = subject.collect
              expect(set.samples).to have_key(:'ruby.gc.time')
            end
          end
        end

        context 'jruby', if: RSpec::Support::Ruby.jruby? do
          it 'collects a metric set and prefixes keys' do
            subject.collect # disable on strict plaforms
            next if subject.disabled?

            set, = subject.collect

            expect(set.samples).to match(
              'ruby.gc.count': Integer,
              'ruby.threads': Integer
            )
          end
        end
      end
    end
  end
end
