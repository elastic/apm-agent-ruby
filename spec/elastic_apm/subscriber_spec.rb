# frozen_string_literal: true

enable = false
begin
  require 'active_support/notifications'
  enable = true
rescue LoadError
  puts '[INFO] Skipping Subscriber spec'
end

if enable
  require 'elastic_apm/subscriber'

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
        it 'adds spans from notifications' do
          agent = Agent.new Config.new(disable_send: true)
          subject = Subscriber.new agent
          transaction = agent.transaction 'Test'

          expect do
            subject.start(
              'process_action.action_controller',
              'id-1',
              controller: 'UsersController', action: 'index'
            )
          end.to change(transaction.spans, :length). by 1

          span = transaction.current_span
          expect(span).to be_running
          expect(span.name).to eq 'UsersController#index'

          subject.finish(
            'process_action.action_controller',
            'id-1',
            nil
          )

          expect(span).to_not be_running
          expect(span).to be_done
        end

        it 'ignores unknown notifications' do
          agent = Agent.new Config.new(disable_send: true)
          subject = Subscriber.new agent
          transaction = agent.transaction 'Test'

          expect do
            subject.start('unknown.notification', nil, {})
          end.to_not change(transaction.spans, :length)
        end
      end
    end
  end
end
