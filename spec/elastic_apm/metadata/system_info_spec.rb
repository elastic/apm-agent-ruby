# frozen_string_literal: true

module ElasticAPM
  RSpec.describe Metadata::SystemInfo do
    describe '#initialize' do
      subject { described_class.new(Config.new) }

      it 'has values' do
        %i[hostname architecture platform].each do |key|
          expect(subject.send(key)).to_not be_nil
        end
      end

      context 'hostname' do
        it 'has no newline at the end' do
          expect(subject.hostname).not_to match(/\n\z/)
        end
      end

    end
  end
end
