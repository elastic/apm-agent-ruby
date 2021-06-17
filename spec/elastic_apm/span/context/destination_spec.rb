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
#
# frozen_string_literal: true

require "spec_helper"

module ElasticAPM
  class Span
    class Context
      RSpec.describe Destination do
        describe ".new" do
          it "initializes with hashes" do
            subject = described_class.new(
              address: 'a',
              port: 80,
              service: { resource: 'b' },
              cloud: { region: 'c' }
            )

            expect(subject.address).to eq 'a'
            expect(subject.port).to eq 80
            expect(subject.service.resource).to eq 'b'
            expect(subject.cloud.region).to eq 'c'
          end
        end

        describe ".from_uri" do
          let(:uri) { URI("http://example.com/path/?a=1") }

          subject { described_class.from_uri(uri) }

          it "parses and initializes correctly" do
            expect(subject.address).to eq("example.com")
            expect(subject.port).to eq(80)

            # deprecated
            expect(subject.service.name).to be(nil)
            expect(subject.service.type).to be(nil)
          end

          context("https") do
            let(:uri) { URI("https://example.com/path?a=1") }

            it "parses and initializes correctly" do
              expect(subject.address).to eq("example.com")
              expect(subject.port).to eq(443)
            end
          end

          context("non-default port") do
            let(:uri) { URI("http://example.com:8080/path?a=1") }

            it "parses and initializes correctly" do
              expect(subject.address).to eq("example.com")
              expect(subject.port).to eq(8080)
            end
          end

          context("when given a string") do
            let(:uri) { "http://example.com/path?a=1" }

            it "parses and initializes correctly" do
              expect(subject.address).to eq("example.com")
              expect(subject.port).to eq(80)
            end
          end

          context("IPv6") do
            let(:uri) { "http://[::1]:8080/" }

            it "parses and initializes correctly" do
              expect(subject.address).to eq("::1")
              expect(subject.port).to eq(8080)
            end
          end

          context("type: http") do
            subject { described_class.from_uri(uri, type: "http") }

            it "adds destination" do
              expect(subject.service.resource).to eq("example.com:80")
            end
          end
        end
      end
    end
  end
end
