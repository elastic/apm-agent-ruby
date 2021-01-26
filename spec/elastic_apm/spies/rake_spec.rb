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
require 'rake'

module ElasticAPM
  RSpec.describe 'Rake', :intercept do
    let(:task) do
      Rake::Task.define_task(:test_task) do
        'ok'
      end
    end

    it 'wraps in transaction when enabled' do
      with_agent(instrumented_rake_tasks: %w[test_task]) do
        task.invoke
      end

      expect(@intercepted.transactions.length).to eq 1
      expect(@intercepted.transactions.first.outcome).to eq 'success'
    end

    context 'when disabled' do
      it 'wraps in transaction when enabled' do
        with_agent do
          task.invoke
        end

        expect(@intercepted.transactions.length).to eq 0
      end
    end

    context 'when the task fails' do
      let(:task) do
        Rake::Task.define_task(:failed_task) do
          raise StandardError
        end
      end

      it 'sets the transaction outcome to `failure`' do
        with_agent(instrumented_rake_tasks: %w[failed_task]) do
          begin
            task.invoke
          rescue StandardError
          end
        end

        expect(@intercepted.transactions.length).to eq 1
        expect(@intercepted.transactions.first.outcome).to eq 'failure'
      end
    end
  end
end
