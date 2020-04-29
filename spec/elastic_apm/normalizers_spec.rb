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

enable = false
begin
  require 'active_support/notifications'
  enable = true
rescue LoadError
  puts '[INFO] Skipping Normalizers spec'
end

if enable
  require 'elastic_apm/subscriber'

  module ElasticAPM
    RSpec.describe Normalizers do
      describe 'registration:' do
        it 'allows a normalizer to register itself' do
          class TestNormalizer < Normalizers::Normalizer
            register 'something'
          end

          built = Normalizers.build nil
          expect(built.for('something')).to be_a TestNormalizer
          expect(built.keys).to include 'something'
        end
      end
    end
  end
end
