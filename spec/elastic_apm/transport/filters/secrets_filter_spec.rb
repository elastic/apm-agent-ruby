# frozen_string_literal: true

module ElasticAPM
  module Transport
    module Filters
      RSpec.describe SecretsFilter do
        let(:config) { Config.new }
        subject { described_class.new(config) }

        it 'removes secret keys from requests' do
          payload = { transaction: { context: { request: { headers: {
            ApiKey: 'very zecret!',
            Untouched: 'very much',
            TotallyNotACreditCard: '4111 1111 1111 1111'
          } } } } }

          subject.call(payload)

          headers = payload.dig(:transaction, :context, :request, :headers)

          expect(headers).to match(
            ApiKey: '[FILTERED]',
            Untouched: 'very much',
            TotallyNotACreditCard: '[FILTERED]'
          )
        end

        it 'removes secret keys from responses' do
          payload = { transaction: { context: { response: { headers: {
            ApiKey: 'very zecret!',
            Untouched: 'very much',
            TotallyNotACreditCard: '4111 1111 1111 1111'
          } } } } }

          subject.call(payload)

          headers = payload.dig(:transaction, :context, :response, :headers)

          expect(headers).to match(
            ApiKey: '[FILTERED]',
            Untouched: 'very much',
            TotallyNotACreditCard: '[FILTERED]'
          )
        end

        it 'removes secrets from form bodies' do
          payload = { transaction: { context: { request: {
            body: +'api_key=secret&credit_card=4111111111111111'
          } } } }

          subject.call(payload)

          body = payload.dig(:transaction, :context, :request, :body)
          expect(body).to eq('api_key=[FILTERED]&credit_card=[FILTERED]')
        end

        context 'with custom_key_filters' do
          let(:config) { Config.new(custom_key_filters: [/Authorization/]) }

          it 'removes Authorization header' do
            payload = { transaction: { context: { request: { headers: {
              Authorization: 'Bearer some',
              SomeHeader: 'some'
            } } } } }

            subject.call(payload)

            headers = payload.dig(:transaction, :context, :request, :headers)

            expect(headers).to match(
              Authorization: '[FILTERED]',
              SomeHeader: 'some'
            )
          end
        end
      end
    end
  end
end
