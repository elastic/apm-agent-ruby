# frozen_string_literal: true

module ElasticAPM
  RSpec.describe Util do
    describe '.micros', mock_time: true do
      it 'returns current µs since unix epoch' do
        expect(Util.micros).to eq 694_224_000_000_000
      end
    end

    describe '.monotonic_micros' do
      it 'returns current processor microseconds' do
        expect(Util.monotonic_micros.to_s).to match(/\d+/)
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

    describe '.reverse_merge!' do
      it 'merges hashes into one, destructively' do
        first = { a: 1 }
        second = { b: 2, c: 3 }
        third = { b: 'interception!' }

        Util.reverse_merge!(first, second, third)

        expect(first).to match(a: 1, b: 'interception!', c: 3)
      end
    end
  end
end
