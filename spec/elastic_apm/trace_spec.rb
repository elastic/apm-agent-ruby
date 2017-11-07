# frozen_string_literal: true

module ElasticAPM
  RSpec.describe Trace do
    describe '#start', :mock_time do
      it 'has a relative and absolute start time', :mock_time do
        transactionish = Struct.new(:timestamp).new(Util.micros)

        trace = Trace.new(transactionish, nil, 'test-1')
        travel 100
        trace.start

        expect(trace.relative_start).to eq 100_000
      end
    end

    describe '#done', :mock_time do
      it 'sets duration' do
        transactionish = Struct.new(:timestamp).new(Util.micros)
        subject = Trace.new(transactionish, nil, 'test-1')

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
        transactionish = Struct.new(:timestamp).new(Util.micros)
        subject = Trace.new(transactionish, nil, 'test-1')

        expect(subject).to_not be_running

        subject.start

        expect(subject).to be_running

        subject.done

        expect(subject).to_not be_running
      end
    end
  end
end
