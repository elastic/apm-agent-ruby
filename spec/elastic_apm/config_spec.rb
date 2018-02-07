# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  RSpec.describe Config do
    it 'has defaults' do
      config = Config.new
      expect(config.server_url).to eq 'http://localhost:8200'
    end

    it 'overwrites defaults' do
      config = Config.new(server_url: 'somewhere-else.com')
      expect(config.server_url).to eq 'somewhere-else.com'
    end

    it 'takes options from ENV' do
      ENV['ELASTIC_APM_SERVER_URL'] = 'by-env!'
      config = Config.new

      expect(config.server_url).to eq 'by-env!'

      ENV.delete('ELASTIC_APM_SERVER_URL') # clean up
    end

    it 'converts certain env values to integers' do
      ENV['ELASTICS_APM_SOURCE_LINES_SPAN_APP_FRAMES'] = '666'
      config = Config.new
      expect(config.source_lines_span_app_frames).to be 666
      ENV.delete('ELASTICS_APM_SOURCE_LINES_SPAN_APP_FRAMES') # clean up
    end

    it 'yields itself to a given block' do
      config = Config.new { |c| c.server_url = 'somewhere-else.com' }
      expect(config.server_url).to eq 'somewhere-else.com'
    end
  end
end
