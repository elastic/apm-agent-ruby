# frozen_string_literal: true

module ElasticAPM
  RSpec.describe Context::Response do
    it 'converts header values to string' do
      resp = described_class.new(
        nil,
        headers: {
          a: 1,
          b: '2',
          c: [1, 2, 3]
        }
      )

      expect(resp.headers).to match(
        a: '1',
        b: '2',
        c: '[1, 2, 3]'
      )
    end
  end
end
