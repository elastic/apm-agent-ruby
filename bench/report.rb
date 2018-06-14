#!/usr/bin/env ruby
# frozen_string_literal: true

Encoding.default_external = 'utf-8'

require 'time'
require 'bundler/setup'
require 'faraday'
require 'json'

ELASTICSEARCH_URL = ENV.fetch('CLOUD_ADDR') { '' }.chomp
if ELASTICSEARCH_URL == ''
  puts 'ELASTICSEARCH_URL missing, exiting ...'
  exit 1
end

input = STDIN.read.split("\n")
puts input

titles = input.grep(/^===/).map { |t| t.gsub(/^=== /, '') }
counts = input.grep(/^Count: /).map { |a| a.gsub(/^Count: /, '').to_i }
averages = input.grep(/^avg/).map { |a| a.match(/\((.+)\)/)[1].to_f }

git_sha, git_date, git_msg = `git log -n 1 --pretty="format:%H|||%ai|||%s"`.split('|||')
platform = Gem::Platform.local

payloads = titles.zip(averages, counts).map do |(title, avg, count)|
  {
    title: title,
    avg: avg,
    transaction_count: count,
    executed_at: Time.new.iso8601,
    'git.commit' => git_sha,
    'git.date' => Time.parse(git_date).iso8601,
    'git.subject' => git_msg,
    hostname: `hostname`.chomp,
    engine: RUBY_ENGINE,
    arch: platform.cpu,
    os: platform.os,
    ruby_version: RUBY_VERSION
  }
end

puts '=== Reporting to ES'

CONN = Faraday.new(url: ELASTICSEARCH_URL) do |f|
  f.response :logger
  f.adapter Faraday.default_adapter
end

payloads.each do |payload|
  result = CONN.post('/benchmark-ruby/_doc') do |req|
    req.headers['Content-Type'] = 'application/json'
    req.body = payload.to_json
  end

  puts result.body unless (200...300).include?(result.status)
end
