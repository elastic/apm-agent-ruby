# Licensed to Elasticsearch B.V. under one or more contributor
# license agreements. See the NOTICE file distributed with
# this work for additional information regarding copyright
# ownership. Elasticsearch B.V. licenses this file to you under
# the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  RSpec.describe StacktraceBuilder do
    let(:config) { Config.new }
    subject { described_class.new(config) }

    describe '.build' do
      context 'mri', unless: RSpec::Support::Ruby.jruby? do
        it 'builds from a backtrace' do
          stacktrace =
            subject.build(actual_exception.backtrace, type: :error)
          expect(stacktrace.frames).to_not be_empty

          # so meta
          last_frame = stacktrace.frames.first
          expect(last_frame.lineno).to be_a Integer
          expect(last_frame.abs_path).to_not be_nil
          expect(last_frame.function).to eq '/'
          expect(last_frame.vars).to be_nil

          expect(last_frame.pre_context.last).to match(/def actual_exception/)
          expect(last_frame.context_line).to match(%r{1 / 0})
          expect(last_frame.post_context.first).to match(/rescue/)
          expect(last_frame.filename).to eq 'support/exception_helpers.rb'
        end
      end

      context 'jruby', if: RSpec::Support::Ruby.jruby? do
        def java_exception
          require 'java'
          java_import 'java.lang.ClassNotFoundException'
          java.lang::Class.forName('foo.Bar')
        rescue ClassNotFoundException => e
          e
        end

        it 'builds from a backtrace' do
          stacktrace =
            subject.build(actual_exception.backtrace, type: :error)
          expect(stacktrace.frames).to_not be_empty

          # so meta
          last_frame = stacktrace.frames.first
          expect(last_frame.lineno).to be_a Integer
          expect(last_frame.abs_path).to_not be_nil
          expect(last_frame.vars).to be_nil

          # JRuby 9.2 reports stacktraces differently
          unless PlatformHelpers.jruby_92?
            expect(last_frame.function).to eq('/')
            expect(last_frame.filename).to eq('org/jruby/RubyFixnum.java')
          end
        end

        it 'builds from a Java exception' do
          stacktrace =
            subject.build(java_exception.backtrace, type: :error)
          expect(stacktrace.frames).to_not be_empty
        end
      end

      it 'initializes from caller' do
        stacktrace = subject.build(caller, type: :span)
        expect(stacktrace.frames).to_not be_empty
      end

      context 'with stack trace limit' do
        let(:config) { Config.new stack_trace_limit: 5 }

        it 'shortens to limit' do
          result = subject.build(actual_exception.backtrace, type: :error)
          expect(result.length).to be 5
        end
      end
    end

    describe '#to_a' do
      it 'is an array' do
        array =
          subject.build(actual_exception.backtrace, type: :error).to_a
        expect(array).to be_a Array
      end
    end

    context 'determining lib frames' do
      [
        # rubocop:disable Layout/LineLength
        [false, "#{Config.new.__root_path}/app/controllers/somethings_controller.rb:5:in `render'"],
        [true, "/Users/someone/.rubies/ruby-2.5.0/lib/ruby/2.5.0/irb/workspace.rb:85:in `eval'"],
        [true, "/usr/local/lib/ruby/site_ruby/2.5.0/bundler/friendly_errors.rb:122:in `yield'"],
        [true, "/Users/someone/.gem/ruby/2.5.0/gems/railties-5.1.5/lib/rails.rb:24:in `whatever'"],
        [true, "/app/vendor/bundle/ruby/2.5.0/bundler/gems/apm-agent-ruby-8135f18735fb/lib/elastic_apm/subscriber.rb:10:in `things'"],
        [true, "/app/vendor/ruby-2.5.0/lib/ruby/2.5.0/benchmark.rb:10:in `things'"],
        [true, "org/jruby/RubyBasicObject.java:1728:in `instance_exec'"],
        [true, "/tmp/vendor/j9.1/jruby/2.3.0/bin/rspec:1:in `<main>'"],
        [true, "/usr/local/lib/ruby/gems/2.5.0/gems/bundler-1.16.1/lib/bundler/friendly_errors.rb:122:in `yield'"]
        # rubocop:enable Layout/LineLength
      ].each do |(expected, frame)|
        it "is #{expected} for #{"#{frame[0..60]}..."}" do
          stacktrace = subject.build([frame], type: :error)
          frame, = stacktrace.frames
          expect(frame.library_frame).to be(expected), frame.inspect
        end
      end
    end
  end
end
