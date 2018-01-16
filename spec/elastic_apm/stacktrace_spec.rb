# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  RSpec.describe Stacktrace do
    describe '.from' do
      context 'mri', unless: RSpec::Support::Ruby.jruby? do
        it 'initializes from a backtrace' do
          stacktrace = Stacktrace.build(Config.new, actual_exception.backtrace)
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
          expect(last_frame.filename).to eq 'spec_helper.rb'

          # library_frame
          expect(last_frame.library_frame).to be false

          gems_frame = stacktrace.frames[-4]

          expect(gems_frame.library_frame).to be true
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

        it 'initializes from an exception' do
          stacktrace = Stacktrace.build(Config.new, actual_exception.backtrace)
          expect(stacktrace.frames).to_not be_empty

          # so meta
          last_frame = stacktrace.frames.first
          expect(last_frame.lineno).to be_a Integer
          expect(last_frame.abs_path).to_not be_nil
          expect(last_frame.function).to eq '/'
          expect(last_frame.vars).to be_nil

          expect(last_frame.filename).to eq 'org/jruby/RubyFixnum.java'
        end

        it 'initializes from a Java exception' do
          stacktrace = Stacktrace.build(Config.new, java_exception.backtrace)
          expect(stacktrace.frames).to_not be_empty
        end
      end

      it 'initializes from caller' do
        stacktrace = Stacktrace.build(Config.new, caller)
        expect(stacktrace.frames).to_not be_empty
      end
    end

    describe '#to_a' do
      it 'is a hash' do
        array = Stacktrace.build(Config.new, actual_exception.backtrace).to_a
        expect(array).to be_a Array
      end
    end
  end
end
