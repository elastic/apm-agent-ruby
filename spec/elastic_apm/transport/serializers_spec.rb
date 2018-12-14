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
        expect(subject.metrics).to be_a Serializers::MetricsSerializer
        expect(subject.metadata).to be_a Serializers::MetadataSerializer
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

      describe '#keyword_field' do
        class TruncateSerializer < Serializers::Serializer
          def serialize(obj)
            { test: keyword_field(obj[:test]) }
          end
        end

        it 'truncates values to 1024 chars' do
          obj = { test: 'X' * 2000 }
          thing = TruncateSerializer.new(Config.new).serialize(obj)
          expect(thing[:test]).to match(/X{1023}…/)
        end
      end

      describe '#keyword_object' do
        class TruncateSerializer < Serializers::Serializer
          def serialize(obj)
            keyword_object(obj)
          end
        end

        it 'truncates values to 1024 chars' do
          obj = { test: 'X' * 2000 }
          thing = TruncateSerializer.new(Config.new).serialize(obj)
          expect(thing[:test]).to match(/X{1023}…/)
        end
      end
    end
  end
end
