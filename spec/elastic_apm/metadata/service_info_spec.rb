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
  RSpec.describe Metadata::ServiceInfo do
    describe '#initialize' do
      subject do
        described_class.new(
          Config.new(
            service_name: "my-service",
            service_node_name: "my-node"
          )
        )
      end

      its(:name) { is_expected.to eq "my-service" }
      its(:node_name) { is_expected.to eq "my-node" }

      it 'knows the runtime (mri)', unless: RSpec::Support::Ruby.jruby? do
        expect(subject.runtime.name).to eq 'ruby'
        expect(subject.runtime.version).to_not be_nil
      end

      it 'knows the runtime (JRuby)', if: RSpec::Support::Ruby.jruby? do
        expect(subject.runtime.name).to eq 'jruby'
        expect(subject.runtime.version).to_not be_nil
      end

      it 'has a version from git' do
        expect(subject.version).to match(/[a-z0-9]{16}/) # git sha
      end
    end
  end
end
