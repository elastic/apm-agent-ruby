# frozen_string_literal: true

module ElasticAPM
  module Transport
    module Serializers
      RSpec.describe ContextSerializer do
        let(:config) { Config.new }
        subject { described_class.new config }

        it 'converts response.status_code to int' do
          context = Context.new
          context.response = Context::Response.new('302')
          result = subject.build(context)
          expect(result.dig(:response, :status_code)).to be 302
        end
      end
    end
  end
end
