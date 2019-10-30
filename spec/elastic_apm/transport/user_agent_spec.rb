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
              \Aelastic-apm-ruby/(\d+\.)+\d+\s
              http.rb/(\d+\.)+\d+\s
              j?ruby/(\d+\.)+\d+\z
            }x
          )
        end
      end
    end
  end
end
