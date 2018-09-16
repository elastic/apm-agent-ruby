# frozen_string_literal: true

module ElasticAPM
  module Transport
    module Filters
      RSpec.describe RequestBodyFilter do
        subject { described_class.new(Config.new) }

        describe '#call' do
          it 'strips request body' do
            payload = {
              transaction: {
                context: {
                  request: {
                    body: 'very secret stuff'
                  }
                }
              }
            }

            result = subject.call(payload)

            expect(result).to match(
              transaction: {
                context: {
                  request: {
                    body: '[FILTERED]'
                  }
                }
              }
            )
          end
        end
      end
    end
  end
end
