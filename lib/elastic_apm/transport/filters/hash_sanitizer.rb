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

require 'elastic_apm/util/deep_dup'

module ElasticAPM
  module Transport
    module Filters
      class HashSanitizer
        FILTERED = '[FILTERED]'

        # DEPRECATED: Remove these additions in next major version
        LEGACY_KEY_FILTERS = [/cookie/i, /auth/i].freeze

        # DEPRECATED: Remove this check in next major version
        VALUE_FILTERS = [
          # (probably) credit card number
          /^\d{4}[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}$/
        ].freeze

        def initialize(key_patterns:)
          @key_patterns = key_patterns + LEGACY_KEY_FILTERS
        end

        attr_accessor :key_patterns

        def strip_from(obj)
          strip_from!(Util::DeepDup.dup(obj))
        end

        def strip_from!(obj)
          return unless obj&.is_a?(Hash)

          obj.each do |k, v|
            if filter_key?(k)
              next obj[k] = FILTERED
            end

            case v
            when Hash
              strip_from!(v)
            when String
              if filter_value?(v)
                obj[k] = FILTERED
              end
            end
          end
        end

        def filter_key?(key)
          @key_patterns.any? { |regex| regex.match(key) }
        end

        def filter_value?(value)
          VALUE_FILTERS.any? { |regex| regex.match(value) }
        end
      end
    end
  end
end
