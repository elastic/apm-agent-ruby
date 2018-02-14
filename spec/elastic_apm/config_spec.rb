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
      [
        # [ 'NAME', 'VALUE', 'EXPECTED' ]
        ['ELASTIC_APM_SOURCE_LINES_ERROR_APP_FRAMES', '666', 666],
        ['ELASTIC_APM_SOURCE_LINES_SPAN_APP_FRAMES', '666', 666],
        ['ELASTIC_APM_SOURCE_LINES_ERROR_LIBRARY_FRAMES', '666', 666],
        ['ELASTIC_APM_SOURCE_LINES_SPAN_LIBRARY_FRAMES', '666', 666],
        ['ELASTIC_APM_TRANSACTION_SAMPLE_RATE', '0.5', 0.5],
        ['ELASTIC_APM_VERIFY_SERVER_CERT', '1', true],
        ['ELASTIC_APM_VERIFY_SERVER_CERT', 'true', true],
        ['ELASTIC_APM_VERIFY_SERVER_CERT', '0', false],
        ['ELASTIC_APM_VERIFY_SERVER_CERT', 'false', false],
        [
          'ELASTIC_APM_ENABLED_ENVIRONMENTS',
          'test,production',
          %w[test production]
        ]
      ].each do |(key, val, expected)|
        val_before = ENV[key]
        ENV[key] = val
        setting = key.gsub('ELASTIC_APM_', '').downcase
        expect(Config.new.send(setting.to_sym)).to eq expected
        val_before ? ENV[key] = val_before : ENV.delete(key)
      end
    end

    it 'yields itself to a given block' do
      config = Config.new { |c| c.server_url = 'somewhere-else.com' }
      expect(config.server_url).to eq 'somewhere-else.com'
    end
  end
end
