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
  module Transport
    RSpec.describe Filters do
      subject { described_class.new(Config.new) }

      it 'initializes with config' do
        expect(subject).to be_a Filters::Container
      end

      describe '#add' do
        it 'can add more filters' do
          expect do
            subject.add(:thing, -> {})
          end.to change(subject, :length).by 1
        end
      end

      describe '#remove' do
        it 'removes filter by key' do
          expect do
            subject.remove(:secrets)
          end.to change(subject, :length).by(-1)
        end
      end

      describe '#apply!' do
        it 'applies all filters to payload' do
          subject.add(:purger, ->(_payload) { {} })
          result = subject.apply!(things: 1)
          expect(result).to eq({})
        end

        it 'aborts if a filter returns nil' do
          untouched = double(call: nil)

          subject.add(:niller, ->(_payload) {})
          subject.add(:untouched, untouched)

          result = subject.apply!(things: 1)

          expect(result).to be Filters::SKIP
          expect(untouched).to_not have_received(:call)
        end
      end

      describe 'from multiple threads' do
        it "doesn't complain" do
          threads =
            (0...100).map do |i|
              Thread.new do
                if i.even?
                  subject.apply!(payload: i)
                else
                  subject.add :"filter_#{i}", ->(_) { '' }
                end
              end
            end

          threads.each(&:join)
        end
      end
    end
  end
end
