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

RSpec.configure do |config|
  config.before :each, mock_time: true do
    @mocked_time = Time.utc(1992, 1, 1)
    @mocked_clock = 123_000

    def travel(us)
      Timecop.freeze(@mocked_time += (us / 1_000_000.0))
      @mocked_clock += us
    end

    allow(ElasticAPM::Util).to receive(:monotonic_micros) { @mocked_clock }

    travel 0
  end

  config.after :each, mock_time: true do
    Timecop.return
  end
end
