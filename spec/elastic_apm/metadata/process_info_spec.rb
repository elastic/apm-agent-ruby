# frozen_string_literal: true

module ElasticAPM
  module Metadata
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
end
