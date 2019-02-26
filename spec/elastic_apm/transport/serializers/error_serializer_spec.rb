# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  module Transport
    module Serializers
      RSpec.describe ErrorSerializer do
        let(:config) { Config.new }
        let(:agent) { Agent.new config }

        let(:builder) { described_class.new config }

        before do
          @mock_uuid = SecureRandom.uuid
          allow(SecureRandom).to receive(:uuid) { @mock_uuid }
        end

        describe '#build', :mock_time do
          context 'an error with exception' do
            let(:error) do
              ErrorBuilder.new(agent).build_exception(actual_exception)
            end
            subject { builder.build(error) }

            it 'builds', unless: jruby_92? do
              should match(
                error: {
                  id: String,
                  culprit: '/',
                  timestamp: 694_224_000_000_000,
                  context: nil,
                  exception: {
                    message: 'ZeroDivisionError: divided by 0',
                    type: 'ZeroDivisionError',
                    module: '',
                    code: nil,
                    attributes: nil,
                    stacktrace: error.exception.stacktrace.to_a, # so lazy
                    handled: true
                  },
                  parent_id: nil,
                  trace_id: nil,
                  transaction_id: nil,
                  transaction: nil
                }
              )
            end
          end

          context 'an error with a transaction id' do
            it 'attaches the transaction' do
              error = ElasticAPM::Error.new.tap do |e|
                e.transaction_id = 'abc123'
                e.transaction = { sampled: true }
              end
              subject = builder.build(error)
              expect(subject[:error][:transaction_id]).to eq 'abc123'
              expect(subject[:error][:transaction]).to eq(sampled: true)
            end
          end

          context 'a log message' do
            it 'builds' do
              error_log =
                ErrorBuilder.new(agent).build_log('Things')

              result = builder.build(error_log)

              expect(result).to match(
                error: {
                  id: String,
                  context: nil,
                  culprit: nil,
                  log: {
                    message: 'Things',
                    level: nil,
                    logger_name: nil,
                    param_message: nil,
                    stacktrace: []
                  },
                  timestamp: 694_224_000_000_000,
                  trace_id: nil,
                  transaction_id: nil,
                  transaction: nil,
                  parent_id: nil
                }
              )
            end
          end
        end
      end
    end
  end
end
