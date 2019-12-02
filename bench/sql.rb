#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'json'
require 'benchmark'
include Benchmark # rubocop:disable Style/MixinUsage

require 'elastic_apm/sql_summarizer'
require 'elastic_apm/sql/signature'

examples =
  JSON
  .parse(File.read('./spec/fixtures/sql_signature_examples.json'))
  .map { |ex| ex['input'] }

examples = Array.new(100).map { examples }.flatten

puts "#{'=' * 14} Parsing #{examples.length} examples #{'=' * 14}"

summarizer = ElasticAPM::SqlSummarizer.new

benchmark(CAPTION, 7, FORMAT, 'avg/ex:') do |bm|
  old = bm.report('old:') do
    examples.map { |i| summarizer.summarize(i) }
  end
  new = bm.report('new:') do
    examples.map { |i| ElasticAPM::Sql::Signature.parse(i) }
  end

  [(new - old) / examples.length]
end
