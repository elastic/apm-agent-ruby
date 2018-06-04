# frozen_string_literal: true

module ElasticAPM
  RSpec.describe Span::Context do
    describe 'initialize' do
      it 'sets values from keyword args' do
        context = described_class.new(statement: 'BO SELECTA')
        expect(context.statement).to eq 'BO SELECTA'
      end
    end
  end
end
