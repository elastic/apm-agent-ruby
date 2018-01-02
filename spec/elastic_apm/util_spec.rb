# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  RSpec.describe Util do
    describe '.nearest_minute', :mock_time do
      it 'normalizes to nearest minute' do
        travel 125_000 # two minutes five secs
        expect(Util.nearest_minute).to eq Time.utc(1992, 1, 1, 0, 2)
      end
    end

    describe '#ms', mock_time: true do
      it 'returns current µs since unix epoch' do
        expect(Util.micros).to eq 694_224_000_000_000
      end
    end
  end
end
