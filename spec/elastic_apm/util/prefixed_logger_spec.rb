# frozen_string_literal: true

module ElasticAPM
  module Util
    RSpec.describe PrefixedLogger do
      let(:logdev) { StringIO.new }
      subject { described_class.new logdev, prefix: 'PREFIX-' }

      it 'delegates to original logger' do
        expect(logdev).to receive(:write).with(/PREFIX-message/)
        subject.warn 'message'
      end
    end
  end
end
