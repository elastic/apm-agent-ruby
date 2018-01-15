# frozen_string_literal: true

require 'spec_helper'

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
  end
end
