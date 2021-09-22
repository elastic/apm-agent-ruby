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
  RSpec.describe CentralConfig::CacheControl do
    let(:header) { nil }
    subject { described_class.new(header) }

    context 'with max-age' do
      let(:header) { 'max-age=300' }
      its(:max_age) { should be 300 }
      its(:must_revalidate) { should be nil }
    end

    context 'with must-revalidate' do
      let(:header) { 'must-revalidate' }
      its(:max_age) { should be nil }
      its(:must_revalidate) { should be true }
    end

    context 'with multiple values' do
      let(:header) { 'must-revalidate, public, max-age=300' }
      its(:max_age) { should be 300 }
      its(:must_revalidate) { should be true }
      its(:public) { should be true }
      its(:private) { should be nil }
    end
  end
end
