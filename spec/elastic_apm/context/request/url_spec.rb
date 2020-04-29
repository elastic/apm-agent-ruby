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
