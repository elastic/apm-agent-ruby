# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  RSpec.describe Stacktrace::LineCache do
    subject { described_class }

    it 'can get and set values' do
      subject.set(
        'something.rb',
        [1, 2, 3],
        ['LINE 1', 'LINE 2', 'LINE 3']
      )

      expect(subject.get('something.rb', [1, 2, 3])).to eq(
        ['LINE 1', 'LINE 2', 'LINE 3']
      )
    end
  end
end
