# frozen_string_literal: true

module ElasticAPM
  RSpec.describe Span do
    let(:transactionish) do
      Struct
        .new(:id, :timestamp, :instrumenter, :trace_id)
        .new('id', Util.micros, nil, '__trace_id')
    end

    describe '#start', :mock_time do
      it 'has a relative and absolute start time', :mock_time do
        span = Span.new(transactionish, nil, 'test-1')
        travel 100
        span.start

        expect(span.relative_start).to eq 100_000
        expect(span.timestamp).to eq Util.micros - 100_000
      end
    end

    describe '#done', :mock_time do
      it 'sets duration' do
        subject = Span.new(transactionish, nil, 'test-1')

        expect(subject).to_not be_done

        subject.start
        travel 100
        subject.done

        expect(subject).to be_done
        expect(subject.duration).to eq 100_000
      end
    end

    describe '#running?' do
      it 'is when started and not done' do
        subject = Span.new(transactionish, nil, 'test-1')

        expect(subject).to_not be_running

        subject.start

        expect(subject).to be_running

        subject.done

        expect(subject).to_not be_running
      end
    end
  end
end
