# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  RSpec.describe Span do
    describe '#start', :mock_time do
      it 'has a relative and absolute start time', :mock_time do
        transactionish =
          Struct.new(:timestamp, :instrumenter).new(Util.micros, nil)

        span = Span.new(transactionish, nil, 'test-1')
        travel 100
        span.start

        expect(span.relative_start).to eq 100_000
      end
    end

    describe '#done', :mock_time do
      it 'sets duration' do
        transactionish =
          Struct.new(:timestamp, :instrumenter).new(Util.micros, nil)
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
        transactionish =
          Struct.new(:timestamp, :instrumenter).new(Util.micros, nil)
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
