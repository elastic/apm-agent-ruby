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
    class SinatraSpy
      def install
        ::Sinatra::Base.class_eval do
          alias dispatch_without_apm! dispatch!
          alias compile_template_without_apm compile_template

          def dispatch!(*args, &block)
            dispatch_without_apm!(*args, &block).tap do
              next unless (transaction = ElasticAPM.current_transaction)
              next unless (route = env['sinatra.route'])

              transaction.name = route
            end
          end

          def compile_template(engine, data, opts, *args, &block)
            opts[:__elastic_apm_template_name] =
              case data
              when Symbol then data.to_s
              else format('Inline %s', engine)
              end

            compile_template_without_apm(engine, data, opts, *args, &block)
          end
        end
      end
    end

    register 'Sinatra::Base', 'sinatra/base', SinatraSpy.new

    require 'elastic_apm/spies/tilt'
  end
end
