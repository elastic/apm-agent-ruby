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
  RSpec.describe Metadata::SystemInfo do
    describe '#initialize' do
      subject { described_class.new(Config.new) }

      it 'has values' do
        %i[hostname architecture platform].each do |key|
          expect(subject.send(key)).to_not be_nil
        end
      end

      context 'hostname' do
        it 'has no newline at the end' do
          expect(subject.hostname).not_to match(/\n\z/)
        end
      end
    end
  end
end
