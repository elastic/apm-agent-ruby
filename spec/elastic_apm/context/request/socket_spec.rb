# frozen_string_literal: true

module ElasticAPM
  class Context
    class Request
      RSpec.describe Socket do
        subject { described_class.new req }

        context 'with an ip' do
          let(:req) do
            Rack::Request.new(
              Rack::MockRequest.env_for('/', 'REMOTE_ADDR' => '127.0.0.1')
            )
          end

          its(:remote_addr) { is_expected.to eq '127.0.0.1' }
        end

        # 'Trusted' as per Rack's definition:
        # https://github.com/rack/rack/blob/2.0.7/lib/rack/request.rb#L419-L421
        context 'with a "trusted" remote addr and forwarding header' do
          let(:req) do
            Rack::Request.new(
              Rack::MockRequest.env_for(
                '/',
                'REMOTE_ADDR' => '127.0.0.1',
                'HTTP_X_FORWARDED_FOR' => '4.3.2.1'
              )
            )
          end

          its(:remote_addr) { is_expected.to eq '127.0.0.1' }
        end
      end
    end
  end
end
