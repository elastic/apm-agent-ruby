# frozen_string_literal: true

module ElasticAPM
  RSpec.describe Span::Context do
    describe 'initialize' do
      context 'with no args' do
        its(:db) { should be nil }
        its(:http) { should be nil }
      end

      context 'with db' do
        subject { described_class.new db: { statement: 'asd' } }

        it 'adds a db object' do
          expect(subject.db.statement).to eq 'asd'
        end
      end

      context 'with http' do
        subject { described_class.new http: { url: 'asd' } }

        it 'adds a http object' do
          expect(subject.http.url).to eq 'asd'
        end
      end
    end
  end
end
