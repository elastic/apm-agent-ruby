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

if defined?(Rails)
  require 'elastic_apm/subscriber'

  module ElasticAPM
    RSpec.describe Subscriber, :mock_intake do
      let(:config) { Config.new }
      let(:agent) { Agent.new config }

      before do
        MockIntake.stub!
        agent.start
      end

      after { agent.stop }

      subject { Subscriber.new(agent) }

      describe '#register!' do
        it 'subscribes to AS::Notifications' do
          expect(ActiveSupport::Notifications)
            .to receive(:subscribe).with(Regexp, subject)
          subject.register!
        end

        it 'unregisters first if already registered' do
          allow(ActiveSupport::Notifications)
            .to receive(:unsubscribe).and_call_original

          subject.register!
          subject.register!

          expect(ActiveSupport::Notifications)
            .to have_received(:unsubscribe)

          subject.unregister! # clean up
        end
      end

      describe 'AS::Notifications API' do
        it 'adds spans from notifications', :intercept do
          agent.start_transaction 'Test'

          subject.start(
            'process_action.action_controller',
            'id-1',
            controller: 'UsersController', action: 'index'
          )

          span = agent.current_span
          expect(span).to be_running
          expect(span.name).to eq 'UsersController#index'

          subject.finish(
            'process_action.action_controller',
            'id-1',
            nil
          )

          agent.end_transaction

          expect(span).to_not be_running
          expect(span).to be_stopped
        end

        it 'ignores unknown notifications' do
          agent = Agent.new Config.new(disable_send: true)
          subject = Subscriber.new agent
          agent.start_transaction 'Test'

          expect do
            subject.start('unknown.notification', nil, {})
          end.to_not change(agent, :current_span)
        end
      end
    end
  end
end
