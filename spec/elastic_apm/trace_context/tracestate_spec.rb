# frozen_string_literal: true

module ElasticAPM
  RSpec.describe TraceContext::Tracestate do
    describe '.parse' do
      it 'parses a header' do
        result = described_class.parse('a=b')
        expect(result.values).to eq(['a=b'])
      end

      it 'handles multiple values' do
        result = described_class.parse("a=b\nc=d")
        expect(result.values).to eq(['a=b', 'c=d'])
      end
    end

    describe '#to_header' do
      context 'with a single value' do
        subject { described_class.parse('a=b') }
        its(:to_header) { is_expected.to eq 'a=b' }
      end

      context 'with multiple values' do
        subject { described_class.parse("a=b\nc=d") }
        its(:to_header) { is_expected.to eq 'a=b,c=d' }
      end

      context 'with mixed' do
        subject { described_class.parse("a=b,c=d\ne=f") }
        its(:to_header) { is_expected.to eq 'a=b,c=d,e=f' }
      end
    end
  end
end
