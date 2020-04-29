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

RSpec::Matchers.define :delegate do |method, opts|
  to = opts[:to]
  args = opts[:args]

  match do |delegator|
    unless to.respond_to?(method)
      raise NoMethodError, "no method `#{method}` on #{to.inspect}"
    end

    if args
      expect(to).to receive(method).at_least(:once).with(*args) { true }
    else
      expect(to).to receive(method).at_least(:once).with(no_args) { true }
    end

    if args&.last.is_a?(Hash)
      kw = args.pop
      delegator.send method, *args, **kw
    else
      delegator.send method, *args
    end
  end

  description do
    "delegate :#{method} to #{to}"
  end
end
