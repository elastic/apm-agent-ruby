# Licensed to Elasticsearch B.V. under one or more contributor
# license agreements. See the NOTICE file distributed with
# this work for additional information regarding copyright
# ownership. Elasticsearch B.V. licenses this file to you under
# the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

# frozen_string_literal: true

require 'spec_helper'

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
