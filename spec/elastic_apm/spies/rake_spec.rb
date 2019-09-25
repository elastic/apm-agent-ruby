# frozen_string_literal: true

require 'spec_helper'
require 'rake'

module ElasticAPM
  RSpec.describe 'Rake' do
    include_context 'intercept'

    let(:task) do
      Rake::Task.define_task(:test_task) do
        'ok'
      end
    end

    let(:config) { { instrumented_rake_tasks: %w[test_task] } }

    it 'wraps in transaction when enabled' do
      task.invoke
      expect(intercepted.transactions.length).to eq 1
    end

    context 'when disabled' do
      it 'wraps in transaction when enabled' do
        ElasticAPM.start
        task.invoke
        ElasticAPM.stop

        expect(intercepted.transactions.length).to eq 0
      end
    end
  end
end
