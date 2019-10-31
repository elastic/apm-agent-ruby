# frozen_string_literal: true

module ElasticAPM
  module Metrics
    RSpec.shared_examples(:span_scope_set) do
      let(:config) { Config.new }
      subject { described_class.new config }

      describe 'collect' do
        it 'moves transaction info from tags to props' do
          subject.gauge(
            :a,
            tags: { 'transaction.name': 'name', 'transaction.type': 'type' }
          )
          set, = subject.collect
          expect(set.transaction).to match(name: 'name', type: 'type')
        end

        it 'moves span info from tags to props' do
          subject.gauge(
            :a,
            tags: { 'span.type': 'type', 'span.subtype': 'subtype' }
          )
          set, = subject.collect
          expect(set.span).to match(type: 'type', subtype: 'subtype')
        end
      end
    end

    RSpec.describe TransactionSet do
      it_behaves_like :span_scope_set
    end

    RSpec.describe BreakdownSet do
      it_behaves_like :span_scope_set
    end
  end
end
