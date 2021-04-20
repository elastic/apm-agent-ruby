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
  class Span
    class Context
      # @api private
      class Destination

        # @api private
        class Service
          class MissingValues < StandardError; end

          def initialize(name: nil, type: nil, resource: nil)
            @name = name
            @type = type
            @resource = resource

            # APM Server expects all values for service
            raise MissingValues unless @name && @type && resource
          end

          attr_accessor :name, :type, :resource
        end

        # @api private
        class Cloud
          def initialize(region: nil)
            @region = region
          end

          attr_accessor :region
        end

        def initialize(
          address: nil,
          port: nil,
          service: nil,
          cloud: nil
        )
          @address = address
          @port = port
          @service = build_service(service)
          @cloud = build_cloud(cloud)
        end

        attr_reader(
          :address,
          :port,
          :service,
          :cloud
        )

        def self.from_uri(uri_or_str, type: 'external', port: nil)
          uri = normalize(uri_or_str)

          service = Service.new(
            name: only_scheme_and_host(uri),
            resource: "#{uri.host}:#{uri.port}",
            type: type
          )

          new(
            address: uri.hostname,
            port: port || uri.port,
            service: service
          )
        end

        def self.only_scheme_and_host(uri_or_str)
          uri = normalize(uri_or_str)
          uri.path = ''
          uri.password = uri.query = uri.fragment = nil
          uri.to_s
        end

        class << self
          private

          def normalize(uri_or_str)
            return uri_or_str.dup if uri_or_str.is_a?(URI)
            URI(uri_or_str)
          end
        end

        private

        def build_service(service = nil)
          return unless service
          return service if service.is_a?(Service)

          Service.new(**service)
        rescue Service::MissingValues
          nil # If we are missing any service value, return nothing
        end

        def build_cloud(cloud = nil)
          return unless cloud
          return cloud if cloud.is_a?(Cloud)

          Cloud.new(**cloud)
        end
      end
    end
  end
end
