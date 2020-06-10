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
  RSpec.describe Context::User do
    describe '.infer' do
      it 'sets values from passed object' do
        PossiblyUser = Struct.new(:id, :email, :username)
        record = PossiblyUser.new(1, 'a@a', 'abe')

        user = described_class.infer(Config.new, record)
        expect(user.id).to eq '1'
        expect(user.email).to eq 'a@a'
        expect(user.username).to eq 'abe'
      end

      it "doesn't explode with missing methods" do
        expect do
          user = described_class.infer(Config.new, Object.new)
          expect(user.id).to be_nil
          expect(user.email).to be_nil
          expect(user.username).to be_nil
        end.to_not raise_exception
      end
    end

    describe 'empty?' do
      it 'is when new' do
        expect(Context::User.new).to be_empty
      end
    end
  end
end
