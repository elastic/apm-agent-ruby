#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'

require 'benchmark'
include Benchmark

require 'rack/test'

require './bench/app'
include App::Helpers

def perform(app, count: 1000)
  app.start

  transactions = count.times.map do |i|
    ElasticAPM.transaction "Transaction##{i}",
      context: ElasticAPM.build_context(app.mock_env) do
      ElasticAPM.span('Number one') { 'ok 1' }
      ElasticAPM.span('Number two') { 'ok 2' }
      ElasticAPM.span('Number three') { 'ok 3' }
    end
  end

  app.serializer.build_all(transactions)

  app.stop
end

def avg(benchmarks)
  [benchmarks.reduce(Tms.new(0), &:+) / benchmarks.length]
end

def banner(text)
  puts "=== #{text}"
end

def do_bench(transaction_count: 10, **config)
  puts "Count: #{transaction_count} transactions... \n \n"

  bench = Benchmark.benchmark(CAPTION, 7, FORMAT, 'avg:') do |x|
    benchmarks =
      with_app(config) do |app|
        # warm-up
        puts "1 run of warm-up"
        perform(app, count: transaction_count)

        5.times.map do |i|
          x.report("run[#{i}]") { perform(app, count: transaction_count) }
        end
      end

    avg(benchmarks)
  end
end

transaction_count = Integer(ARGV.shift || 100_000)

banner 'Default settings'
do_bench transaction_count: transaction_count

banner 'With transaction_sample_rate = 0'
do_bench(transaction_count: transaction_count, transaction_sample_rate: 0)
