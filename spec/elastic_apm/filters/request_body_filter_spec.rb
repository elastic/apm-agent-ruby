# frozen_string_literal: true

module ElasticAPM
  RSpec.describe Filters::RequestBodyFilter do
    subject { described_class.new(Config.new) }

    describe '#call' do
      it 'strips request body' do
        payload = {
          transactions: [{
            context: {
              request: {
                body: 'very secret stuff'
              }
            }
          }]
        }

        result = subject.call(payload)

        expect(result).to match(
          transactions: [{
            context: {
              request: {
                body: '[FILTERED]'
              }
            }
          }]
        )
      end
    end
  end
end
