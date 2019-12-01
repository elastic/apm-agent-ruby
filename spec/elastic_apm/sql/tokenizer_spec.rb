# frozen_string_literal: true

require 'json'
require './lib/elastic_apm/sql/tokenizer'

module ElasticAPM
  module Sql
    RSpec.describe Tokenizer do
      describe 'examples:' do
        examples =
          JSON.parse(File.read('spec/fixtures/sql_lexer_examples.json'))

        examples.each do |info|
          it info['comment'] do
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
    end
  end
end
