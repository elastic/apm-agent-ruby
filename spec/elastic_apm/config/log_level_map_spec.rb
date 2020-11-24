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

require "spec_helper"

module ElasticAPM
  class Config
    RSpec.describe LogLevelMap do
      subject { described_class.new }

      context 'when the level is an integer' do
        context 'when the level is valid' do
          let(:level) { Logger::DEBUG }
          it 'sets the level' do
            expect(subject.call(level)).to eq(Logger::DEBUG)
          end
        end

        context 'when the level is not valid' do
          let(:level) { 6 }
          it 'sets the default level' do
            expect(subject.call(level)).to eq(Logger::INFO)
          end
        end
      end

      context 'when the level is a string' do
        let(:level) { 'error' }
        it 'sets the mapped level' do
          expect(subject.call(level)).to eq(Logger::ERROR)
        end
      end

      context 'when the level is a symbol' do
        let(:level) { :error }
        it 'sets the mapped level' do
          expect(subject.call(level)).to eq(Logger::ERROR)
        end
      end

      context 'when the level is not in the map' do
        let(:level) { 'ceci_n_est_pas_un_level' }
        it 'sets the default level' do
          expect(subject.call(level)).to eq(Logger::INFO)
        end
      end
    end
  end
end
