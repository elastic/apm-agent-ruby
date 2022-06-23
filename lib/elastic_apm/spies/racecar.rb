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
  module Spies
    # @api private
    class RacecarSpy
      TYPE = 'Kafka'

      # @api private
      module ConsumerSpy
        def process_message(event)
          with_span() do
            super
          end
        end

        def process_batch(event)
          with_span() do
            super
          end
        end
      end

      module ProducerSpy
        def deliver_messages(*args)
          with_span() do
            super
          end
        end
      end

      def install
        Racecar::Consumer.prepend(ConsumerSpy)
        Racecar::Producer.prepend(ProducerSpy)
      end
    end

    register 'Racecar', 'racecar', RacecarSpy.new
  end
end
