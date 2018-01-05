# frozen_string_literal: true

require 'spec_helper'

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
              context: { custom: {}, tags: {} },
              exception: {
                message: 'ZeroDivisionError: divided by 0',
                type: 'ZeroDivisionError',
                module: '',
                code: nil,
                attributes: nil,
                stacktrace: error.exception.stacktrace.to_a, # so lazy
                handled: true
              }
            )
          end
        end

        context 'an error with a transaction id' do
          it 'attaches the transaction' do
            error = Error.new.tap { |e| e.transaction_id = 'abc123' }
            subject = builder.build(error)
            expect(subject[:transaction]).to eq(id: 'abc123')
          end
        end
      end
    end
  end
end
