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
  end
end
