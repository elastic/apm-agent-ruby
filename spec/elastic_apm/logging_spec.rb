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
  RSpec.describe Logging do
    class Tester
      include Logging

      def initialize(config)
        @config = config
      end
    end

    let(:config) do
      Struct.new(:logger, :log_level).new(logger, log_level)
    end

    subject { Tester.new(config) }

    context 'with a logger' do
      let(:logger) { double(Logger) }
      let(:log_level) { nil }

      it 'logs messages' do
        expect(logger).to receive(:warn).with('[ElasticAPM] Things')
        subject.warn 'Things'
      end

      context 'with a level of warn' do
        let(:log_level) { Logger::WARN }

        it 'skips lower level messages' do
          expect(logger).to receive(:warn).with('[ElasticAPM] Things')
          subject.warn 'Things'

          expect(logger).to_not receive(:debug)
          subject.debug 'Debug things'
        end
      end
    end
  end
end
