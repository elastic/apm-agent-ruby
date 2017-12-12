# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  RSpec.describe ServiceInfo do
    describe '#build' do
      subject { described_class.new(Config.new).build }

      it 'builds' do
        should eq(
          name: nil,
          environment: 'test',
          agent: {
            name: 'ruby',
            version: VERSION
          },
          argv: ARGV,
          framework: nil,
          language: {
            name: 'ruby',
            version: RUBY_VERSION
          },
          pid: $PID,
          process_title: $PROGRAM_NAME,
          runtime: {
            name: RUBY_ENGINE,
            version: RUBY_VERSION
          },
          version: `git rev-parse --verify HEAD`.chomp
        )
      end
    end
  end
end
