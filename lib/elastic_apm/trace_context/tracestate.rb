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

module ElasticAPM
  class TraceContext
    # @api private
    class Tracestate
      def initialize(values = [])
        @values = values
      end

      attr_accessor :values

      def self.parse(header)
        # HTTP allows multiple headers with the same name, eg. multiple
        # Set-Cookie headers per response.
        # Rack handles this by joining the headers under the same key, separated
        # by newlines, see https://www.rubydoc.info/github/rack/rack/file/SPEC
        new(String(header).split("\n"))
      end

      def to_header
        values.join(',')
      end
    end
  end
end
