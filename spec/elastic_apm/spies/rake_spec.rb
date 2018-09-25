# frozen_string_literal: true

require 'spec_helper'
require 'rake'

module ElasticAPM
  RSpec.describe 'Rake', :mock_intake do
    let(:task) do
      Rake::Task.define_task(:test_task) do
        'ok'
      end
    end

    it 'wraps in transaction when enabled' do
      ElasticAPM.start(instrumented_rake_tasks: %w[test_task])
      task.invoke
      ElasticAPM.stop

      expect(@mock_intake.transactions.length).to be 1
    end

    context 'when disabled' do
      it 'wraps in transaction when enabled' do
        ElasticAPM.start
        task.invoke
        ElasticAPM.stop

        expect(@mock_intake.transactions.length).to be 0
      end
    end
  end
end
