#!/usr/bin/env ruby
# frozen_string_literal: true

Encoding.default_external = 'utf-8'

require 'time'
require 'bundler/setup'
require 'json'

input = STDIN.read.split("\n")
STDERR.puts input

titles = input.grep(/^===/).map { |t| t.gsub(/^=== /, '') }
counts = input.grep(/^Count: /).map { |a| a.gsub(/^Count: /, '').to_i }
averages = input.grep(/^avg/).map { |a| a.match(/\((.+)\)/)[1].to_f }

git_sha, git_msg = `git log -n 1 --pretty="format:%H|||%s"`.split('|||')
git_date = `git log -n 1 --pretty="format:%ai"`
platform = Gem::Platform.local

payloads = titles.zip(averages, counts).map do |(title, avg, count)|
  return nil unless avg

  {
    title: title,
    avg: avg,
    transaction_count: count,
    executed_at: Time.new.iso8601,
    'git.commit' => git_sha,
    'git.date' => String(git_date).strip != '' && Time.parse(git_date).iso8601,
    'git.subject' => git_msg,
    hostname: `hostname`.chomp,
    engine: RUBY_ENGINE,
    arch: platform.cpu,
    os: platform.os,
    ruby_version: "#{RUBY_ENGINE == 'jruby' ? 'j' : ''}#{RUBY_VERSION}"
  }
end.compact

STDERR.puts '=== Reporting to ES'
STDERR.puts payloads.inspect

payloads.each do |payload|
  puts '{ "index" : { "_index" : "benchmark-ruby", "_type" : "_doc" } }'
  puts payload.to_json
end
