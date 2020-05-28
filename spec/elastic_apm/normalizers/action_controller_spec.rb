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

require 'spec_helper'

require 'elastic_apm/normalizers'
require 'elastic_apm/normalizers/rails'

module ElasticAPM
  module Normalizers
    module ActionController
      RSpec.describe ProcessActionNormalizer do
        it 'registers for name' do
          normalizers = Normalizers.build(nil)
          subject = normalizers.for('process_action.action_controller')

          expect(subject).to be_a ProcessActionNormalizer
        end

        describe '#normalize' do
          it 'sets transaction name from payload' do
            instrumenter = double(Instrumenter)
            subject = ProcessActionNormalizer.new nil
            transaction = Transaction.new instrumenter,
              'Rack', config: Config.new

            result = subject.normalize(
              transaction,
              'process_action.action_controller',
              controller: 'UsersController', action: 'index'
            )
            expected = [
              'UsersController#index',
              'app',
              'controller',
              'action',
              nil
            ]

            expect(result).to eq expected
          end
        end
      end
    end
  end
end
