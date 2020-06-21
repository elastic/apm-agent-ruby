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

require 'allocations' unless defined?(JRUBY_VERSION)

module ElasticAPM
  module Allocations
    if defined?(JRUBY_VERSION)
      ENABLED = false

      def self.count
        nil
      end
    else
      # c extension defines the `count' method
    end

    module Methods
      class Recorder
        def initialize(child_allocations)
          @child_allocations = child_allocations
        end

        attr_reader :count, :self_count

        def start
          @start = Allocations.count
        end

        def stop
          @count = Allocations.count - @start
          @self_count = @count - @child_allocations.count
        end
      end

      def allocations
        @allocations ||= Recorder.new(child_allocations)
      end

      def child_allocations
        @child_allocations ||= ChildAllocations.new
      end

      def child_started
        super # child_durations TODO: refactor with … hooks or something
        child_allocations.start
      end

      def child_stopped
        super # TODO: refactor with … hooks or something
        child_allocations.stop
      end
    end

    class ChildAllocations
      def initialize
        @nesting_level = 0
        @start = nil
        @count = 0
        @mutex = Mutex.new
      end

      attr_reader :count

      def start
        @mutex.synchronize do
          @nesting_level += 1
          @start = Allocations.count if @nesting_level == 1
        end
      end

      def stop
        @mutex.synchronize do
          @nesting_level -= 1
          @count = (Allocations.count - @start) if @nesting_level == 0
        end
      end
    end
  end
end
