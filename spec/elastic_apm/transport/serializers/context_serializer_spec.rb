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

        context 'service' do
          it 'includes the service' do
            context = Context.new
            context.set_service(framework_name: 'Grape', framework_version: '1.2')
            result = subject.build(context)
            expect(result[:service][:framework][:name]).to eq('Grape')
            expect(result[:service][:framework][:version]).to eq('1.2')
          end
        end
      end
    end
  end
end
