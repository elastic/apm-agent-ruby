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

if defined?(Rails)
  RSpec.describe Rails, :intercept do
    describe '.start' do
      it 'starts the agent' do
        begin
          ElasticAPM::Rails.start({})
          expect(ElasticAPM::Agent).to be_running
        ensure
          ElasticAPM.stop
        end
      end
    end

    describe 'Rails console' do
      before do
        module Rails
          class Console; end
        end
      end

      after { Rails.send(:remove_const, :Console) }

      it "doesn't start when console" do
        begin
          ElasticAPM::Rails.start({})
          expect(ElasticAPM.agent).to be nil
          expect(ElasticAPM).to_not be_running
        ensure
          ElasticAPM.stop
        end
      end
    end
  end
end
