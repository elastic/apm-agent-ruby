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
  # @api private
  module CompressionBuffer
    def child_stopped(child)
      super(child)

      if !child.compression_eligible?
        return # report
      end

      return buffer(child) if compression_buffer.nil?
      return if compression_buffer.try_compress(child)

      compression_buffer.compression_buffered = false
      buffer(child)
    end

    attr_accessor :compression_buffer
    attr_accessor :compression_buffered
    alias :compression_buffered? :compression_buffered

    def try_compress(other)
      can_compress =
        if composite?
          try_compress_composite(other)
        else
          try_compress_regular(other)
        end

      return false unless can_compress

      unless composite?
        self.composite = Composite.new(count: 1, sum: duration)
      end

      composite.count += 1
      composite.sum += other.duration

      true
    end

    def try_compress_regular(other)
      return false unless is_same_kind(other)

      if name == other.name
        if duration <= transaction.span_compression_exact_match_duration &&
            other.duration <= transaction.span_compression_exact_match_duration
          self.composite.compression_strategy = Composite::EXACT_MATCH
          return true
        end

        return false
      end

      if duration <= transaction.span_compression_same_kind_max_duration &&
          other.duration <= transaction.span_compression_same_kind_max_duration
        self.composite.compression_strategy = Composite::SAME_KIND
        self.name = "Calls to #{destination.service.resource}"
        return true
      end

      return false
    end

    def is_same_kind(other)
      return false unless type == other.type
      return false unless subtype == other.subtype
      return false unless context.destination&.service&.resource = other.context.destination&.service&.resource

      true
    end

    private

    def buffer(span)
      self.compression_buffer = span
      span.compression_buffered = true
    end
  end
end
