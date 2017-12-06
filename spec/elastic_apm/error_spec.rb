# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  RSpec.describe Error do
    describe 'initialization' do
      subject { Error.new }

      it { expect(subject.timestamp).to_not be nil }
      it { expect(subject.context).to_not be nil }
    end
  end
end
