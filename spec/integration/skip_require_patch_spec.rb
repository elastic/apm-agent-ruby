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

# Deliberately setting this before requiring spec_helper.rb so it's set
# before we require the agent
ENV['ELASTIC_APM_SKIP_REQUIRE_PATCH'] = '1'
require 'spec_helper'

RSpec.describe "Disabling the require hook" do
  it "doesn't add aliased original method" do
    expect { Kernel.method(:require_without_apm) }
      .to raise_error(NameError)
  end
end
