# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  RSpec.describe Error do
    describe 'initialization' do
      subject { Error.new }

      it { expect(subject.timestamp).to_not be nil }
      it { expect(subject.context).to_not be nil }

      it 'has an id' do
        expect(subject.id).to_not be_nil
      end
    end
  end
end
