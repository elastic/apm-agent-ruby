# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  RSpec.describe Stacktrace do
    describe '.from' do
      context 'mri', unless: RSpec::Support::Ruby.jruby? do
        it 'initializes from an exception' do
          stacktrace = Stacktrace.build(nil, actual_exception)
          expect(stacktrace.frames).to_not be_empty

          # so meta
          last_frame = stacktrace.frames.last
          expect(last_frame.lineno).to be_a Integer
          expect(last_frame.abs_path).to_not be_nil
          expect(last_frame.function).to eq '/'
          expect(last_frame.vars).to be_nil

          expect(last_frame.pre_context.last).to match(/def actual_exception/)
          expect(last_frame.context_line).to match(%r{1 / 0})
          expect(last_frame.post_context.first).to match(/rescue/)
          expect(last_frame.filename).to eq 'spec_helper.rb'
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
          stacktrace = Stacktrace.build(nil, actual_exception)
          expect(stacktrace.frames).to_not be_empty

          # so meta
          last_frame = stacktrace.frames.last
          expect(last_frame.lineno).to be_a Integer
          expect(last_frame.abs_path).to_not be_nil
          expect(last_frame.function).to eq '/'
          expect(last_frame.vars).to be_nil

          expect(last_frame.filename).to eq 'org/jruby/RubyFixnum.java'
        end

        it 'initializes from a Java exception' do
          stacktrace = Stacktrace.build(nil, java_exception)
          expect(stacktrace.frames).to_not be_empty
        end
      end
    end

    describe '#to_h' do
      it 'is a hash' do
        hsh = Stacktrace.build(nil, actual_exception).to_h
        expect(hsh).to be_a Hash
        expect(hsh.keys).to eq [:frames]
      end
    end
  end
end
