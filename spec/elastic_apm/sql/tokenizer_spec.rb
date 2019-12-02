# frozen_string_literal: true

require 'elastic_apm/sql/tokenizer'
require 'json'

module ElasticAPM
  module Sql
    RSpec.describe Tokenizer do
      describe 'examples:' do
        examples =
          JSON.parse(File.read('spec/fixtures/sql_tokenizer_examples.json'))

        examples.each do |info|
          desc = info['name']
          desc += ": #{info['comment']}" if info['comment']
          it desc do
            scanner = described_class.new(info['input'])

            info.fetch('tokens', []).each do |expected|
              expect(scanner.scan).to be true
              expect(
                'kind' => scanner.token.to_s,
                'text' => scanner.text
              ).to eq(expected), info['input']
            end
          end
        end
      end

      describe '#scan' do
        it 'is true until end of string' do
          scanner = described_class.new('a b c')
          expect(scanner.scan).to be true
          expect(scanner.scan).to be true
          expect(scanner.scan).to be true
          expect(scanner.scan).to be false
        end
      end
    end
  end
end
