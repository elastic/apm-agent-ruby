# frozen_string_literal: true

module ElasticAPM
  RSpec.describe Trace do
    describe '#initialize', :mock_time do
      it 'gets a timestamp' do
        expect(Trace.new(nil, 'Test').timestamp).to eq Time.now.utc.to_i
      end
    end

    describe '#start', :mock_time do
      it 'has a relative and absolute start time' do
        trace = Trace.new(nil, 'test-1').start 100

        expect(trace.start_time).to eq     694_224_000_000_000_000
        expect(trace.relative_start).to eq 694_223_999_999_999_900
      end
    end

    describe '#done', :mock_time do
      subject { Trace.new(nil, 'test-1') }

      it { should_not be_done }

      it 'sets duration' do
        subject.start 0
        travel 100
        subject.done

        expect(subject).to be_done
        expect(subject.duration).to eq 100_000_000
      end
    end

    describe '#running?' do
      subject { Trace.new(nil, 'test-1') }

      it 'is when started and not done' do
        expect(subject).to_not be_running

        subject.start 0

        expect(subject).to be_running

        subject.done

        expect(subject).to_not be_running
      end
    end
  end
end
