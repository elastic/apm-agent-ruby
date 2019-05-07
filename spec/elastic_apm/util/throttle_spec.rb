# frozen_string_literal: true

require 'elastic_apm/util/throttle'

module ElasticAPM
  module Util
    RSpec.describe Throttle do
      let(:thing) { double call: 'ok' }

      subject { described_class.new(0.1) { thing.call } } # 100 milisecs

      it 'calls only once per 100 milisecs' do
        expect(thing).to receive(:call).once
        5.times { subject.call }

        sleep 0.1

        expect(thing).to receive(:call).once
        5.times { subject.call }
      end

      it 'returns result of last call' do
        subject = described_class.new(1) { 'here it is' }
        expect(subject.call).to eq('here it is')
        expect(subject.call).to eq('here it is')
      end
    end
  end
end
