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
    class ActionDispatchSpy
      def install
        ::ActionDispatch::ShowExceptions.class_eval do
          alias render_exception_without_apm render_exception

          def render_exception(env, exception)
            context = ElasticAPM.build_context(rack_env: env, for_type: :error)
            ElasticAPM.report(exception, context: context, handled: false)

            render_exception_without_apm env, exception
          end
        end
      end
    end

    register(
      'ActionDispatch::ShowExceptions',
      'action_dispatch/show_exception',
      ActionDispatchSpy.new
    )
  end
end
