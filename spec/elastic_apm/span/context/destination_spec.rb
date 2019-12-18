# frozen_string_literal: true

module ElasticAPM
  class Span
    class Context
      RSpec.describe Destination do
        describe '.from_uri' do
          let(:uri) { URI('http://example.com/path/?a=1') }

          subject { described_class.from_uri(uri) }

          its(:name) { is_expected.to eq 'http://example.com' }
          its(:resource) { is_expected.to eq 'example.com:80' }
          its(:type) { is_expected.to eq 'external' }

          context 'https' do
            let(:uri) { URI('https://example.com/path?a=1') }
            its(:name) { is_expected.to eq 'https://example.com' }
            its(:resource) { is_expected.to eq 'example.com:443' }
          end

          context 'non-default port' do
            let(:uri) { URI('http://example.com:8080/path?a=1') }
            its(:name) { is_expected.to eq 'http://example.com:8080' }
            its(:resource) { is_expected.to eq 'example.com:8080' }
          end

          context 'when given a string' do
            let(:uri) { 'http://example.com/path?a=1' }

            its(:name) { is_expected.to eq 'http://example.com' }
            its(:resource) { is_expected.to eq 'example.com:80' }
            its(:type) { is_expected.to eq 'external' }
          end
        end
      end
    end
  end
end
