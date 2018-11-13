# frozen_string_literal: true

module ElasticAPM
  module Transport
    RSpec.describe Serializers do
      subject { described_class.new(Config.new) }

      it 'initializes with config' do
        expect(subject).to be_a Serializers::Container
        expect(subject.transaction).to be_a Serializers::TransactionSerializer
        expect(subject.span).to be_a Serializers::SpanSerializer
        expect(subject.error).to be_a Serializers::ErrorSerializer
      end

      describe '#serialize' do
        it 'serializes known objects' do
          expect(subject.serialize(Transaction.new)).to be_a Hash
          expect(subject.serialize(Span.new('Name'))).to be_a Hash
          expect(subject.serialize(Error.new)).to be_a Hash
        end

        it 'explodes on unknown objects' do
          expect { subject.serialize(Object.new) }
            .to raise_error(Serializers::UnrecognizedResource)
        end
      end
    end
  end
end
