# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  RSpec.describe Subscriber do
    describe '#register!' do
      subject do
        agent = Agent.new Config.new
        Subscriber.new(agent)
      end

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
      it 'adds traces from notifications' do
        agent = Agent.new Config.new
        subject = Subscriber.new agent
        transaction = agent.transaction 'Test'

        expect do
          subject.start(
            'process_action.action_controller',
            'id-1',
            controller: 'UsersController', action: 'index'
          )
        end.to change(transaction.traces, :length). by 1

        trace = transaction.current_trace
        expect(trace).to be_running
        expect(trace.name).to eq 'UsersController#index'

        subject.finish(
          'process_action.action_controller',
          'id-1',
          nil
        )

        expect(trace).to_not be_running
        expect(trace).to be_done
      end

      it 'ignores unknown notifications' do
        agent = Agent.new Config.new
        subject = Subscriber.new agent
        transaction = agent.transaction 'Test'

        expect do
          subject.start('unknown.notification', nil, {})
        end.to_not change(transaction.traces, :length)
      end
    end
  end
end
