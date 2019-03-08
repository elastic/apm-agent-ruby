# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  module Transport
    module Serializers
      RSpec.describe ErrorSerializer do
        let(:config) { Config.new }
        let(:agent) { Agent.new(config) }
        let(:builder) { ErrorBuilder.new(agent) }

        subject { described_class.new(config) }

        context 'with an exception', :mock_time do
          let(:error) do
            builder.build_exception(actual_exception)
          end

          it 'matches format' do
            result = subject.build(error).fetch(:error)

            expect(result).to include(
              id: be_a(String),
              culprit: be_a(String),
              timestamp: 694_224_000_000_000,
              parent_id: nil,
              trace_id: nil,
              transaction_id: nil,
              transaction: nil
            )

            expect(result.fetch(:exception)).to include(
              message: 'ZeroDivisionError: divided by 0',
              type: 'ZeroDivisionError',
              module: '',
              code: nil,
              attributes: nil,
              stacktrace: be_an(Array),
              handled: true
            )
          end

          context 'with a context' do
            let(:error) do
              env = Rack::MockRequest.env_for('/')
              context =
                agent.context_builder.build(rack_env: env, for_type: :error)
              builder.build_exception(actual_exception, context: context)
            end

            it 'includes context' do
              context = subject.build(error).fetch(:error).fetch(:context)

              expect(context).to include(
                custom: {},
                tags: {},
                user: nil,
                request: be_a(Hash)
              )
            end
          end
        end

        context 'with a log', :mock_time do
          let(:error) do
            builder.build_log('oh no!')
          end

          it 'matches format' do
            result = subject.build(error).fetch(:error)

            expect(result).to include(
              id: be_a(String),
              culprit: nil,
              timestamp: 694_224_000_000_000,
              parent_id: nil,
              trace_id: nil,
              transaction_id: nil,
              transaction: nil
            )

            expect(result.fetch(:log)).to include(
              level: nil,
              logger_name: nil,
              message: 'oh no!',
              param_message: nil,
              stacktrace: []
            )
          end
        end
      end
    end
  end
end
