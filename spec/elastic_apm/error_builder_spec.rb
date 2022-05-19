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

module ElasticAPM
  RSpec.describe ErrorBuilder do
    let(:config) { Config.new }

    subject { ErrorBuilder.new Agent.new(config) }

    context 'with an exception' do
      it 'builds an error from an exception', :mock_time,
        unless: PlatformHelpers.jruby_92? do
        error = subject.build_exception(actual_exception)

        expect(error.culprit).to eq '/'
        expect(error.timestamp).to eq 694_224_000_000_000
        expect(error.exception.message).to eq 'divided by 0'
        expect(error.exception.type).to eq 'ZeroDivisionError'
        expect(error.exception.handled).to be true
      end

      it 'sets properties from current transaction', :intercept do
        env = Rack::MockRequest.env_for(
          '/somewhere/in/there?q=yes',
          method: 'POST'
        )
        env['HTTP_CONTENT_TYPE'] = 'application/json'

        transaction =
          with_agent(default_labels: { more: 'totes' }) do
            context =
              ElasticAPM.build_context rack_env: env, for_type: :transaction

            ElasticAPM.with_transaction('/somewhere/in/there', context: context) do |txn|
              ElasticAPM.set_label(:my_tag, '123')
              ElasticAPM.set_custom_context(all_the_other_things: 'blah blah')
              ElasticAPM.set_user(Struct.new(:id).new(321))
              ElasticAPM.report actual_exception

              txn
            end
          end

        error = @intercepted.errors.last
        expect(error.transaction).to eq(sampled: true, type: 'custom')
        expect(error.transaction_id).to eq transaction.id
        expect(error.transaction_name).to eq transaction.name
        expect(error.trace_id).to eq transaction.trace_id
        expect(error.context.labels).to match(my_tag: '123', more: 'totes')
        expect(error.context.custom)
          .to match(all_the_other_things: 'blah blah')
      end
    end

    context 'with a log' do
      it 'builds an error from a message', :mock_time,
        unless: PlatformHelpers.jruby_92? do
        error = subject.build_log 'Things went BOOM', backtrace: caller

        expect(error.culprit).to eq 'instance_exec'
        expect(error.log.message).to eq 'Things went BOOM'
        expect(error.timestamp).to eq 694_224_000_000_000
        expect(error.log.stacktrace).to be_a Stacktrace
        expect(error.log.stacktrace.length).to be > 0
      end
    end
  end
end
