# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  RSpec.describe Logging do
    class Tester
      include Logging

      def initialize(config)
        @config = config
      end
    end

    let(:config) do
      Struct.new(:logger, :log_level).new(logger, log_level)
    end

    subject { Tester.new(config) }

    context 'with a logger' do
      let(:logger) { double(Logger) }
      let(:log_level) { nil }

      it 'logs messages' do
        expect(logger).to receive(:warn).with('[ElasticAPM] Things')
        subject.warn 'Things'
      end

      context 'with a level of warn' do
        let(:log_level) { Logger::WARN }

        it 'skips lower level messages' do
          expect(logger).to receive(:warn).with('[ElasticAPM] Things')
          subject.warn 'Things'

          expect(logger).to_not receive(:debug)
          subject.debug 'Debug things'
        end
      end
    end
  end
end
