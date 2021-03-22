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
    class S3Spy
      TYPE = 'storage'
      SUBTYPE = 's3'
      AP_REGION_REGEX = /^(?:[^:]+:){3}([^:]+).*/
      AP_REGEX = /:accesspoint.*/
      MUTEX = Mutex.new

      @@formatted_op_names = {}

      def self.without_net_http
        return yield unless defined?(NetHTTPSpy)

        # rubocop:disable Style/ExplicitBlockArgument
        ElasticAPM::Spies::NetHTTPSpy.disable_in do
          yield
        end
        # rubocop:enable Style/ExplicitBlockArgument
      end

      def self.bucket_name(params)
        if params[:bucket]
          if index = params[:bucket].rindex(AP_REGEX)
            params[:bucket][index+1..-1]
          else
            params[:bucket]
          end
        end
      end

      def self.accesspoint_region(params)
        if params[:bucket] && (match = AP_REGION_REGEX.match(params[:bucket]))
          match[1]
        end
      end

      def self.span_name(operation_name, bucket_name)
        bucket_name ? "S3 #{formatted_op_name(operation_name)} #{bucket_name}" :
          "S3 #{formatted_op_name(operation_name)}"
      end

      def self.formatted_op_name(operation_name)
        if @@formatted_op_names[operation_name]
          return @@formatted_op_names[operation_name]
        end

        MUTEX.synchronize do
          if @@formatted_op_names[operation_name]
            return @@formatted_op_names[operation_name]
          end

          @@formatted_op_names[operation_name] =
            operation_name.to_s.split('_').collect(&:capitalize).join
        end

        @@formatted_op_names[operation_name]
      end


      def install
        ::Aws::S3::Client.class_eval do
          # Alias all available operations
          api.operation_names.each do |operation_name|
            alias :"#{operation_name}_without_apm" :"#{operation_name}"

            define_method(operation_name) do |params = {}, options = {}|
              bucket_name = ElasticAPM::Spies::S3Spy.bucket_name(params)
              cloud = ElasticAPM::Span::Context::Destination::Cloud.new(
                region: ElasticAPM::Spies::S3Spy.accesspoint_region(params) || config.region
              )

              context = ElasticAPM::Span::Context.new(
                destination: {
                  cloud: cloud,
                  resource: bucket_name,
                  type: TYPE,
                  name: SUBTYPE
                }
              )

              ElasticAPM.with_span(
                ElasticAPM::Spies::S3Spy.span_name(operation_name, bucket_name),
                TYPE,
                subtype: SUBTYPE,
                action: ElasticAPM::Spies::S3Spy.formatted_op_name(operation_name),
                context: context
              ) do
                ElasticAPM::Spies::S3Spy.without_net_http do
                  original_method = method("#{operation_name}_without_apm")
                  original_method.call(params, options)
                end
              end
            end
          end
        end
      end
    end

    register(
      'Aws::S3::Client',
      'aws-sdk-s3',
      S3Spy.new
    )
  end
end
