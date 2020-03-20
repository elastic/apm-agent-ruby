# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  RSpec.describe Metadata::ServiceInfo do
    describe '#initialize' do
      let(:config) { Config.new }
      subject do
        described_class.new(
        service_name: config.service_name,
        framework_name: config.framework_name,
        framework_version: config.framework_version,
        service_version: config.service_version)
      end

      it 'knows the runtime (mri)', unless: RSpec::Support::Ruby.jruby? do
        expect(subject.runtime.name).to eq 'ruby'
        expect(subject.runtime.version).to_not be_nil
      end

      it 'knows the runtime (JRuby)', if: RSpec::Support::Ruby.jruby? do
        expect(subject.runtime.name).to eq 'jruby'
        expect(subject.runtime.version).to_not be_nil
      end

      it 'has a version from git' do
        expect(subject.version).to match(/[a-z0-9]{16}/) # git sha
      end
    end
  end
end
