# frozen_string_literal: true

require 'elastic_apm/sql/signature'
require 'json'

module ElasticAPM
  module Sql
    RSpec.describe Signature do
      describe 'examples:' do
        examples =
          JSON.parse(File.read('spec/fixtures/sql_signature_examples.json'))

        examples.each_with_index.each do |info, i|
          desc = "0#{i}"[-2..-1] + ': '

          if info['comment']
            desc += info['comment']
          else
            desc += info['input'][0...60].inspect
            desc += ' => '
            desc += info['output'].inspect
          end

          it(desc) do
            expect(described_class.parse(info['input'])).to eq(info['output'])
          end
        end
      end
    end
  end
end
