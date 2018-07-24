# frozen_string_literal: true

require 'spec_helper'
require 'rake'

module ElasticAPM
  RSpec.describe 'Rake', :with_fake_server do
    let(:task) do
      Rake::Task.define_task(:test_task) do
        'ok'
      end
    end

    it 'wraps in transaction when enabled' do
      ElasticAPM.start(instrument_rake: true)

      task.invoke

      expect(FakeServer.requests.length).to be 1
    end

    context 'when disabled' do
      it 'wraps in transaction when enabled' do
        ElasticAPM.start
        task.invoke
        expect(FakeServer.requests.length).to be 0
      end
    end
  end
end
