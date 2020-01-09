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

        context 'when given auth info' do
          subject do
            described_class.new(
              http: { url: 'https://user%40email.com:pass@example.com/q=a@b' }
              #                         %40 => @
            )
          end

          it 'omits the password' do
            expect(subject.http.url).to eq 'https://user%40email.com@example.com/q=a@b'
          end
        end
      end

      context 'with destination' do
        subject do
          described_class.new(
            destination: { name: 'nam', resource: 'res', type: 'typ' }
          )
        end

        it 'adds a Destination object' do
          expect(subject.destination.name).to eq 'nam'
          expect(subject.destination.resource).to eq 'res'
          expect(subject.destination.type).to eq 'typ'
        end
      end
    end
  end
end
