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
      # @api private
      class Entry
        def initialize(key, value)
          @key, @value = key, value
          parse! if key == 'es'
        end

        attr_reader :key, :values

        def set(k, v)
          if key != 'es'
            raise ArgumentError,
              'trying to set a value in a non-Elastic tracestate entry'
          end

          @values[k.to_s] = v.to_s
        end

        def get(k)
          value[k.to_s]
        end

        def value
          return @value unless values
          values.map { |(k, v)| "#{k}:#{v}" }.join(';')
        end

        def to_s
          "#{key}=#{value}"
        end

        private

        def parse!
          @values = Hash[value.split(';').map { |kv| kv.split(':') }]
        end
      end

      def initialize(entries = {})
        @entries = entries
      end

      attr_accessor :entries

      def self.parse(header)
        entries =
          split_by_nl_and_comma(header)
          .each_with_object({}) do |entry, hsh|
            k, v = entry.split('=')
            hsh[k] = Entry.new(k, v)
          end

        new(entries)
      end

      def sample_rate
        es_entry.get(:s)
      end

      def sample_rate=(value)
        es_entry.set(:s, value)
      end

      def to_header
        entries.values.map(&:to_s).join(',')
      end

      private

      def es_entry
        entries['es'] ||= Entry.new('es', '')
        entries['es']
      end

      class << self
        private

        def split_by_nl_and_comma(str)
          # HTTP allows multiple headers with the same name, eg. multiple
          # Set-Cookie headers per response.
          # Rack handles this by joining the headers under the same key, separated
          # by newlines, see https://www.rubydoc.info/github/rack/rack/file/SPEC
          String(str).split("\n").map { |s| s.split(',') }.flatten
        end
      end
    end
  end
end
