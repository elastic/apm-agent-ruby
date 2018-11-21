# frozen_string_literal: true

module ElasticAPM
  RSpec.describe Util do
    describe '.nearest_minute', :mock_time do
      it 'normalizes to nearest minute' do
        travel 125_000 # two minutes five secs
        expect(Util.nearest_minute).to eq Time.utc(1992, 1, 1, 0, 2)
      end
    end

    describe '.ms', mock_time: true do
      it 'returns current µs since unix epoch' do
        expect(Util.micros).to eq 694_224_000_000_000
      end
    end

    describe '.truncate' do
      it 'returns nil on nil' do
        expect(Util.truncate(nil)).to be nil
      end

      it 'return string if shorter than max' do
        expect(Util.truncate('poof')).to eq 'poof'
      end

      it 'returns a truncated string' do
        result = Util.truncate('X' * 2000)
        expect(result).to match(/\AX{1023}…\z/)
        expect(result.length).to be 1024
      end
    end
  end
end
