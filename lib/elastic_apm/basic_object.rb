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
#
# frozen_string_literal: true

module ElasticAPM
  module BasicObject
    module InstanceMethods
      def initialize(**attrs)
        attrs.each do |key, value|
          self.send(:"#{key}=", value)
        end

        super()
      end
    end

    module ClassMethods
      def field(key)
        attr_accessor(key)
        fields.push(key)
      end

      attr_reader :fields
    end

    def self.included(cls)
      cls.extend(ClassMethods)
      cls.include(InstanceMethods)

      cls.instance_variable_set(:@fields, [])
    end
  end
end
