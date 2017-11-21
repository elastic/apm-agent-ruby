# frozen_string_literal: true

require 'spec_helper'
require 'elastic_apm/injectors/tilt'

module ElasticAPM
  RSpec.describe Injectors::TiltInjector do
    it 'registers' do
      registration =
        Injectors.require_hooks['tilt/template'] || # with no tilt present
        Injectors.installed['Tilt::Template']       # when tilt present

      expect(registration.injector).to be_a described_class
    end
  end
end
