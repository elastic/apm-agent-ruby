# frozen_string_literal: true

require 'spec_helper'
require 'rake'

module ElasticAPM
  RSpec.describe 'Rake', :intercept do
    let(:task) do
      Rake::Task.define_task(:test_task) do
        'ok'
      end
    end

    it 'wraps in transaction when enabled' do
      with_agent(instrumented_rake_tasks: %w[test_task]) do
        task.invoke
      end

      expect(@intercepted.transactions.length).to eq 1
    end

    context 'when disabled' do
      it 'wraps in transaction when enabled' do
        with_agent do
          task.invoke
        end

        expect(@intercepted.transactions.length).to eq 0
      end
    end
  end
end
