# frozen_string_literal: true

module ElasticAPM
  module Transport
    RSpec.describe Connection::State do
      it { should be_disconnected }

      describe 'setters' do
        it 'changes state' do
          subject.connecting!
          expect(subject).to be_connecting

          subject.connected!
          expect(subject).to be_connected

          subject.disconnected!
          expect(subject).to be_disconnected
        end
      end
    end
  end
end
