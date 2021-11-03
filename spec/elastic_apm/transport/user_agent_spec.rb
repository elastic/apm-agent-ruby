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
      subject { described_class.new(config) }

      context 'when there is no service name or version' do
        let(:regexp) do
          %r{
            \Aelastic-apm-ruby\/(\d+\.)+\d([a-z0-9\.]+)?+
          }x
        end

        let(:config) { Config.new }

        it 'builds a string' do
          expect(subject.to_s).to match(regexp)
        end

        it 'handles beta versions' do
          subject = described_class.new(config, version: '12.13.14.beta.20')
          expect(subject.to_s).to match(regexp)
        end
      end

      context 'when there is service name only' do
        let(:regexp) do
          %r{
            \Aelastic-apm-ruby/(\d+\.)+\d([a-z0-9\.]+)?+\s
            \(MyService\)
          }x
        end

        let(:config) { Config.new(service_name: "MyService") }

        it 'builds a string' do
          expect(subject.to_s).to match(regexp)
        end
      end

      context 'when there is service name and version' do
        let(:regexp) do
          %r{
            \Aelastic-apm-ruby\/(\d+\.)+\d([a-z0-9\.]+)?+\s
            \(MyService\sv42\)
          }x
        end

        let(:config) do
          Config.new(service_name: "MyService", service_version: 'v42')
        end

        it 'builds a string' do
          expect(subject.to_s).to match(regexp)
        end
      end
    end
  end
end
