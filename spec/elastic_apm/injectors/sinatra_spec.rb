# frozen_string_literal: true

require 'spec_helper'
require 'elastic_apm/injectors/sinatra'

module ElasticAPM
  RSpec.describe Injectors::SinatraInjector do
    it 'registers' do
      registration =
        Injectors.require_hooks['sinatra/base'] || # when no sinatra present
        Injectors.installed['Sinatra::Base']       # with sinatra present

      expect(registration.injector).to be_a described_class
    end
  end
end
