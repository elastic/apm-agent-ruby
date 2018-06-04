# frozen_string_literal: true

module ElasticAPM
  RSpec.describe Filters::SecretsFilter do
    subject { described_class.new(Config.new) }

    it 'removes secret keys from requests' do
      payload = {
        transactions: [{
          context: {
            request: {
              headers: {
                ApiKey: 'very zecret!',
                Untouched: 'very much',
                TotallyNotACreditCard: '4111 1111 1111 1111'
              }
            }
          }
        }]
      }

      subject.call(payload)

      expect(payload).to match(
        transactions: [{
          context: {
            request: {
              headers: {
                ApiKey: '[FILTERED]',
                Untouched: 'very much',
                TotallyNotACreditCard: '[FILTERED]'
              }
            }
          }
        }]
      )
    end

    it 'removes secret keys from responses' do
      payload = {
        transactions: [{
          context: {
            response: {
              headers: {
                ApiKey: 'very zecret!',
                Untouched: 'very much',
                TotallyNotACreditCard: '4111 1111 1111 1111'
              }
            }
          }
        }]
      }

      subject.call(payload)

      expect(payload).to match(
        transactions: [{
          context: {
            response: {
              headers: {
                ApiKey: '[FILTERED]',
                Untouched: 'very much',
                TotallyNotACreditCard: '[FILTERED]'
              }
            }
          }
        }]
      )
    end

    context 'with custom_key_filters' do
      let(:config) { Config.new(custom_key_filters: [/Authorization/]) }
      subject { described_class.new(config) }

      it 'removes Authorization header' do
        payload = {
          transactions: [{
            context: {
              request: {
                headers: {
                  Authorization: 'Bearer some',
                  SomeHeader: 'some'
                }
              }
            }
          }]
        }

        subject.call(payload)

        expect(payload).to match(
          transactions: [{
            context: {
              request: {
                headers: {
                  Authorization: '[FILTERED]',
                  SomeHeader: 'some'
                }
              }
            }
          }]
        )
      end
    end
  end
end
