# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  RSpec.describe ServiceInfo do
    describe '#build' do
      subject { described_class.new(Config.new).build }

      it { should be_a Hash }

      it 'knows the runtime (mri)', unless: RSpec::Support::Ruby.jruby? do
        expect(subject[:runtime]).to eq(name: 'ruby', version: RUBY_VERSION)
      end

      it 'knows the runtime (JRuby)', if: RSpec::Support::Ruby.jruby? do
        expect(subject[:runtime])
          .to eq(name: 'jruby', version: ENV['JRUBY_VERSION'])
      end

      it 'has a version from git' do
        expect(subject[:version]).to eq `git rev-parse --verify HEAD`.chomp
      end
    end
  end
end
