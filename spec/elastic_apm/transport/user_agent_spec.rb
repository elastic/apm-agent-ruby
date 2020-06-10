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
  module Transport
    RSpec.describe UserAgent do
      let(:config) { Config.new }
      subject { described_class.new(config) }

      describe 'to_s' do
        it 'builds a string' do
          expect(subject.to_s).to match(
            %r{
              \Aelastic-apm-ruby/(\d+\.)+\d+\s
              http.rb/(\d+\.)+\d+\s
              j?ruby/(\d+\.)+\d+\z
            }x
          )
        end
      end
    end
  end
end
