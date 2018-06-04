# frozen_string_literal: true

module ElasticAPM
  RSpec.describe Error::Log do
    describe '#initialize' do
      it 'takes a message and optional attributes' do
        log = Error::Log.new 'Things', level: 'debug'
        expect(log.message).to eq 'Things'
        expect(log.level).to eq 'debug'
      end
    end
  end
end
