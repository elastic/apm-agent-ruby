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
    module Serializers
      RSpec.describe MetadataSerializer do
        subject { described_class.new Config.new }
        let(:result) { subject.build(metadata) }

        describe '#build' do
          let(:metadata) { Metadata.new Config.new }

          it 'is a bunch of hashes and no labels' do
            expect(result[:metadata]).to be_a Hash
            expect(result[:metadata][:service]).to be_a Hash
            expect(result[:metadata][:process]).to be_a Hash
            expect(result[:metadata][:system]).to be_a Hash
            expect(result[:metadata][:labels]).to be_nil
          end

          context 'when there are global_labels' do
            let(:metadata) do
              Metadata.new Config.new(global_labels: { apples: 'oranges' })
            end

            it 'is a bunch of hashes' do
              expect(result[:metadata]).to be_a Hash
              expect(result[:metadata][:service]).to be_a Hash
              expect(result[:metadata][:process]).to be_a Hash
              expect(result[:metadata][:system]).to be_a Hash
              expect(result[:metadata][:labels]).to be_a Hash
            end
          end
        end
      end
    end
  end
end
