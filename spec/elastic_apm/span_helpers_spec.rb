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
  RSpec.describe SpanHelpers do
    class Thing
      include ElasticAPM::SpanHelpers

      def do_the_thing
        'ok'
      end
      span_method :do_the_thing

      def self.do_all_things
        'all ok'
      end
      span_class_method :do_all_things

      def do_the_block_thing(&block)
        block.call
      end
      span_method :do_the_block_thing
    end

    context 'on class methods', :intercept do
      it 'wraps in a span' do
        with_agent do
          ElasticAPM.with_transaction do
            Thing.do_all_things
          end
        end

        expect(@intercepted.spans.length).to be 1
        expect(@intercepted.spans.last.name).to eq 'do_all_things'
      end
    end

    context 'on instance methods', :intercept do
      it 'wraps in a span' do
        thing = Thing.new

        with_agent do
          ElasticAPM.with_transaction do
            thing.do_the_thing
          end
        end

        expect(@intercepted.spans.length).to be 1
        expect(@intercepted.spans.last.name).to eq 'do_the_thing'
      end

      it 'handles blocks' do
        thing = Thing.new

        with_agent do
          ElasticAPM.with_transaction do
            thing.do_the_block_thing { 'ok' }
          end
        end

        expect(@intercepted.spans.length).to be 1
        expect(@intercepted.spans.last.name).to eq 'do_the_block_thing'
      end
    end
  end
end
