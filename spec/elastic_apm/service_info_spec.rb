# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  RSpec.describe ServiceInfo do
    describe '#build' do
      subject { described_class.new(Config.new).build }

      it { should be_a Hash }

      it 'knows the runtime (mri)', unless: RSpec::Support::Ruby.jruby? do
        expect(subject[:runtime][:name]).to eq 'ruby'
        expect(subject[:runtime][:version]).to_not be_nil
      end

      it 'knows the runtime (JRuby)', if: RSpec::Support::Ruby.jruby? do
        expect(subject[:runtime][:name]).to eq 'jruby'
        expect(subject[:runtime][:version]).to_not be_nil
      end

      it 'has a version from git' do
        expect(subject[:version]).to match(/[a-z0-9]{16}/) # git sha
      end
    end
  end
end
