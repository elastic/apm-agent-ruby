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
  RSpec.describe Fields do
    class MyObject
      include Fields

      field :name
      field :address
      field :online, default: true
    end

    it "adds an initializer and accessors" do
      subject = MyObject.new(name: "thing")
      expect(subject.name).to(eq("thing"))
    end

    it "knows its fields" do
      expect(MyObject.schema.keys).to eq(%i[name address online])
    end

    describe "with default value" do
      it 'sets value to default' do
        subject = MyObject.new
        expect(subject.online).to be true
      end

      it 'is overridable' do
        subject = MyObject.new(online: false)
        expect(subject.online).to be false
      end
    end

    describe "#empty?" do
      it "is when missing all values" do
        subject = MyObject.new
        subject.online = nil
        expect(subject).to be_empty
      end

      it "isn't when all fields set" do
        subject = MyObject.new(name: 'a', address: 'b')
        expect(subject).to_not be_empty
      end
    end

    describe "#to_h" do
      it "serializes into a hash" do
        subject = MyObject.new(name: 'a', address: 'b')
        expect(subject.to_h).to match(
          name: 'a',
          address: 'b',
          online: true
        )
      end
    end
  end
end
