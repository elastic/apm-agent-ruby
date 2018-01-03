# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  RSpec.describe ProcessInfo do
    describe '#build' do
      subject { described_class.new(Config.new).build }

      it { should be_a Hash }

      it 'knows about the process' do
        expect(subject).to match(
          argv: Array,
          pid: Integer,
          title: /rspec/
        )
      end
    end
  end
end
