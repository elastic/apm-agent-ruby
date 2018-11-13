# frozen_string_literal: true

module ElasticAPM
  module Transport
    RSpec.describe Filters do
      subject { described_class.new(Config.new) }

      it 'initializes with config' do
        expect(subject).to be_a Filters::Container
      end

      describe '#add' do
        it 'can add more filters' do
          expect do
            subject.add(:thing, -> {})
          end.to change(subject, :length).by 1
        end
      end

      describe '#remove' do
        it 'removes filter by key' do
          expect do
            subject.remove(:secrets)
          end.to change(subject, :length).by(-1)
        end
      end

      describe '#apply!' do
        it 'applies all filters to payload' do
          subject.add(:purger, ->(_payload) { {} })
          result = subject.apply!(things: 1)
          expect(result).to eq({})
        end

        it 'aborts if a filter returns nil' do
          untouched = double(call: nil)

          subject.add(:niller, ->(_payload) { nil })
          subject.add(:untouched, untouched)

          result = subject.apply!(things: 1)

          expect(result).to be_nil
          expect(untouched).to_not have_received(:call)
        end
      end
    end
  end
end
