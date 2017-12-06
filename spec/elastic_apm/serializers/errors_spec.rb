# frozen_string_literal: true

module ElasticAPM
  module Serializers
    RSpec.describe Errors do
      let(:config) { Config.new }
      subject { Errors.new config }
      before { allow(SecureRandom).to receive(:uuid) { '_RANDOM' } }

      describe '#build' do
        it 'builds an error from exception', :mock_time do
          error = ErrorBuilder.new(config).build(actual_exception)

          result = subject.build([error]).dig(:errors, 0)
          expect(result[:id]).to eq '_RANDOM'
          expect(result[:culprit]).to eq '/'
          expect(result[:timestamp]).to eq(Time.utc(1992, 1, 1).iso8601)
          expect(result[:exception]).to eq(
            message: 'ZeroDivisionError: divided by 0',
            type: 'ZeroDivisionError',
            module: '',
            code: nil,
            attributes: nil,
            stacktrace: error.exception.stacktrace.to_h, # so lazy
            unhandled: false
          )
        end
      end
    end
  end
end
