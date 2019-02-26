# frozen_string_literal: true

module ElasticAPM
  RSpec.describe Error do
    describe 'initialization' do
      subject { Error.new }

      its(:id) { should_not be nil }
      its(:timestamp) { should_not be nil }
    end
  end
end
