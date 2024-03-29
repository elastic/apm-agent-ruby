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

module WithAgent
  def with_agent(klass: ElasticAPM, args: [], **config)
    unless @mock_intake || @intercepted
      raise 'Using with_agent but neither MockIntake nor Intercepted'
    end

    @central_config_stub ||=
      WebMock.stub_request(
        :get, %r{^http://localhost:8200/config/v1/agents/?$}
      ).to_return(body: '{}')

    @server_version_stub =
      WebMock.stub_request(:get, %r{^http://localhost:8200/$}).
      to_return(body: '{"version":"8.0"}')

    klass.start(*args, **config)
    yield
  ensure
    ElasticAPM.stop

    @central_config_stub = nil
    @server_version_stub = nil
  end
end
