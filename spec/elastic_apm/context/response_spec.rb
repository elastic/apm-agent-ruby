# frozen_string_literal: true

module ElasticAPM
  RSpec.describe Context::Response do
    let(:response) do
      described_class.new(
        nil,
        headers: headers
      )
    end

    let(:headers) do
      {
        a: 1,
        b: '2',
        c: [1, 2, 3]
      }
    end

    it 'converts header values to string' do
      expect(response.headers).to match(
        a: '1',
        b: '2',
        c: '[1, 2, 3]'
      )
    end

    context 'when headers are nil' do
      let(:headers) { nil }
      it 'sets headers to nil' do
        expect(response.headers).to eq(nil)
      end
    end
  end
end
