#!/usr/bin/env ruby
# frozen_string_literal: true

# Encoding.default_external = 'utf-8'

require 'time'
require 'json'

input = STDIN.read.split("\n")

git_sha, git_msg = `git log -n 1 --pretty="format:%H|||%s"`.split('|||')
git_date = `git log -n 1 --pretty="format:%ai"`
platform = Gem::Platform.local

results =
  input
  .grep(/^with/)
  .map do |line|
    title = line.match(/^(.*):/) { |m| m[1] }
    user, system, total, real = line.scan(/[0-9\.]+/).map(&:to_f)
    {
      title: title,
      user: user,
      system: system,
      total: total,
      real: real,
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
  end

puts '{ "index" : { "_index" : "benchmark-ruby", "_type" : "_doc" } }'
results.each { |result| puts result.to_json }
