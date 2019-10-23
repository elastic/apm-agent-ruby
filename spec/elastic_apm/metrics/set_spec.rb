# frozen_string_literal: true

module ElasticAPM
  module Metrics
    RSpec.describe Set do
      let(:config) { Config.new }
      subject { described_class.new config }

      describe 'disabled?' do
        it 'can be disabled' do
          expect(subject).to_not be_disabled
          subject.disable!
          expect(subject).to be_disabled
        end
      end

      describe 'metrics' do
        it 'can have metrics' do
          subject.gauge('gauge').value = 0
          subject.counter('counter').value = 0
          subject.timer('timer').value = 0

          expect(subject.metrics.length).to be 3
        end

        it 'returns existing metrics' do
          first = subject.gauge('gauge')

          expect(subject.gauge('gauge')).to be first
          expect(subject.metrics.length).to be 1
        end

        it 'adds cardinality with tags' do
          first = subject.gauge('gauge', tags: { a: 1 })
          second = subject.gauge('gauge', tags: { a: 2 })
          expect(first).to_not be second
          expect(subject.metrics.keys).to match(
            [
              ['gauge', :a, 1],
              ['gauge', :a, 2]
            ]
          )
        end

        it 'makes noop metrics after reaching max amount' do
          expect(config.logger).to receive(:warn).with(/limit/) { true }
          stub_const('ElasticAPM::Metrics::Set::DISTINCT_LABEL_LIMIT', 3)

          4.times { |i| subject.gauge('gauge', tags: { a: i }) }

          expect(subject.metrics.length).to be 4
          expect(subject.metrics.values.last).to be NOOP
        end
      end

      describe 'collect' do
        it 'collects all metrics' do
          subject.gauge(:gauge).value = 0
          subject.counter(:counter).value = 0
          subject.timer(:timer).value = 0

          set, = subject.collect
          expect(set).to be_a Metricset
          expect(set.samples).to match(
            gauge: 0,
            counter: 0,
            timer: 0
          )
        end

        it 'skips nil metrics' do
          subject.gauge(:gauge).value = nil
          set, = subject.collect
          expect(set).to be nil
        end

        it 'splits sets by tags' do
          subject.gauge('gauge', tags: { a: 1 })
          subject.gauge('gauge', tags: { a: 2 })

          sets = subject.collect

          expect(sets.length).to be 2
        end
      end
    end
  end
end
