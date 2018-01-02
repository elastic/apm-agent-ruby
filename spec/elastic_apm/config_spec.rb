# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  RSpec.describe Config do
    it 'has defaults' do
      config = Config.new
      expect(config.server).to eq 'http://localhost:8200'
    end

    it 'overwrites defaults' do
      config = Config.new(server: 'somewhere-else.com')
      expect(config.server).to eq 'somewhere-else.com'
    end

    it 'yields itself to a given block' do
      config = Config.new { |c| c.server = 'somewhere-else.com' }
      expect(config.server).to eq 'somewhere-else.com'
    end
  end
end
