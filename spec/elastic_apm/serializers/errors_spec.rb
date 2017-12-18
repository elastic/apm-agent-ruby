# frozen_string_literal: true

module ElasticAPM
  module Serializers
    RSpec.describe Errors do
      let(:config) { Config.new }

      let(:builder) { Errors.new config }
      before do
        @mock_uuid = SecureRandom.uuid
        allow(SecureRandom).to receive(:uuid) { @mock_uuid }
      end

      describe '#build', :mock_time do
        context 'an error with exception' do
          let(:error) do
            ErrorBuilder.new(config).build_exception(actual_exception)
          end
          subject { builder.build(error) }

          it 'builds' do
            should eq(
              id: @mock_uuid,
              culprit: '/',
              timestamp: Time.utc(1992, 1, 1).iso8601,
              exception: {
                message: 'ZeroDivisionError: divided by 0',
                type: 'ZeroDivisionError',
                module: '',
                code: nil,
                attributes: nil,
                stacktrace: error.exception.stacktrace.to_a, # so lazy
                unhandled: false
              }
            )
          end
        end
      end
    end
  end
end
