# frozen_string_literal: true

module ElasticAPM
  module Transport
    RSpec.describe UserAgent do
      let(:config) { Config.new }
      subject { described_class.new(config) }

      describe 'to_s' do
        it 'builds a string' do
          expect(subject.to_s).to match(
            %r{
              elastic-apm-ruby/\d+\.\d+\.\d+\s
              http\.rb/\d+\.\d+\.\d+\s
              ruby/\d+\.\d+\.\d+
            }x
          )
        end
      end
    end
  end
end
