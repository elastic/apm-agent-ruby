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
else
  # DEBUG
  # puts ELASTICSEARCH_URL.gsub(/:[^\/]+(.*)@/) do |m|
  #   ":#{Array.new(m.length - 2).map { '*' }.join}@"
  # end
end

CONN = Faraday.new(url: ELASTICSEARCH_URL) do |f|
  # f.response :logger
  f.adapter Faraday.default_adapter
end

healthcheck = CONN.get('/microbenchmark*/_search')
if healthcheck.status != 200
  puts healthcheck.body.to_s
  exit 1
end

input = STDIN.read.split("\n")
puts input

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
    'git.date' => git_date && Time.parse(git_date).iso8601,
    'git.subject' => git_msg,
    hostname: `hostname`.chomp,
    engine: RUBY_ENGINE,
    arch: platform.cpu,
    os: platform.os,
    ruby_version: "#{RUBY_ENGINE == 'jruby' ? 'j' : ''}#{RUBY_VERSION}"
  }
end.compact

puts '=== Reporting to ES'
puts payloads.inspect

payloads.each do |payload|
  result = CONN.post('/benchmark-ruby/_doc') do |req|
    req.headers['Content-Type'] = 'application/json'
    req.body = payload.to_json
  end

  puts result.body unless (200...300).include?(result.status)
end
