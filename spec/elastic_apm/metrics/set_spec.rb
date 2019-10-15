# frozen_string_literal: true

module ElasticAPM
  module Metrics
    RSpec.describe Set do
      let(:config) { nil }
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

        it 'adds cardinality with labels' do
          first = subject.gauge('gauge', labels: { a: 1 })
          second = subject.gauge('gauge', labels: { a: 2 })
          expect(first).to_not be second
          expect(subject.metrics.keys).to match([
            ['gauge', :a, 1],
            ['gauge', :a, 2],
          ])
        end
      end

      describe 'collect' do
        it 'collects all metrics' do
          subject.gauge(:gauge).value = 0
          subject.counter(:counter).value = 0
          subject.timer(:timer).value = 0

          expect(subject.collect).to match(
            gauge: 0,
            counter: 0,
            timer: 0
          )
        end

        it 'extends a passed hash' do
          subject.gauge(:gauge).value = 0

          data = { existing: true }

          expect(subject.collect(data)).to match(
            gauge: 0,
            existing: true
          )
        end
      end
    end
  end
end
