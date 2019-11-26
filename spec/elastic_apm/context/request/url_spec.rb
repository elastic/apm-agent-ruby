# frozen_string_literal: true

module ElasticAPM
  class Context
    class Request
      RSpec.describe Url do
        context 'from a rack req' do
          let(:url) { 'https://elastic.co:8080/nested/path?abc=123' }
          let(:req) { Rack::Request.new(Rack::MockRequest.env_for(url)) }

          subject { described_class.new(req) }

          its(:protocol) { is_expected.to eq 'https' }
          its(:hostname) { is_expected.to eq 'elastic.co' }
          its(:port) { is_expected.to eq '8080' }
          its(:pathname) { is_expected.to eq '/nested/path' }
          its(:search) { is_expected.to eq 'abc=123' }
          its(:hash) { is_expected.to eq nil }
          its(:full) { is_expected.to eq url }
        end
      end
    end
  end
end
