# frozen_string_literal: true

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

    it 'loads from config file' do
      config = Config.new(config_file: 'spec/fixtures/elastic_apm.yml')
      expect(config.server_url).to eq 'somewhere-config.com'
    end

    it 'takes options from ENV' do
      ENV['ELASTIC_APM_SERVER_URL'] = 'by-env!'
      config = Config.new

      expect(config.server_url).to eq 'by-env!'

      ENV.delete('ELASTIC_APM_SERVER_URL') # clean up
    end

    it 'converts certain env values to Ruby types' do
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
        ],
        ['ELASTIC_APM_CUSTOM_KEY_FILTERS', 'Auth,Other', [/Auth/, /Other/]],
        [
          'ELASTIC_APM_DEFAULT_TAGS',
          'test=something something&other=ok',
          { 'test' => 'something something', 'other' => 'ok' }
        ]
      ].each do |(key, val, expected)|
        val_before = ENV[key]
        ENV[key] = val
        setting = key.gsub('ELASTIC_APM_', '').downcase
        expect(Config.new.send(setting.to_sym)).to eq expected
        val_before ? ENV[key] = val_before : ENV.delete(key)
      end
    end

    context 'custom_key_filters' do
      it 'sets custom_key_filters to array of regexp' do
        config = Config.new(custom_key_filters: [/Authorization/, 'String'])
        expect(config.custom_key_filters).to eq [/Authorization/, /String/]
      end
    end

    context 'ignore_url_patterns' do
      it 'sets ignore_url_patterns to array of regexp' do
        config = Config.new(
          ignore_url_patterns: [
            'PingController#index',
            'GET /ping'
          ]
        )
        expect(config.ignore_url_patterns).to eq [
          /PingController#index/,
          %r{GET /ping}
        ]
      end
    end

    it 'yields itself to a given block' do
      config = Config.new { |c| c.server_url = 'somewhere-else.com' }
      expect(config.server_url).to eq 'somewhere-else.com'
    end

    it 'has spies and may disable them' do
      expect(Config.new.available_spies).to_not be_empty

      config = Config.new disabled_spies: ['json']
      expect(config.enabled_spies).to_not include('json')
    end

    context 'logging' do
      it "writes to stdout with '-'" do
        config = Config.new log_path: '-'
        expect($stdout).to receive(:write).with(/This test ran$/)
        config.logger.info 'This test ran'
      end

      it 'can write to a file' do
        Tempfile.open 'elastic-apm' do |file|
          config = Config.new log_path: file.path
          config.logger.info 'This test ran'

          expect(file.read).to match(/This test ran$/)
        end
      end

      it 'can be given a logger' do
        logger = double(Logger)
        config = Config.new logger: logger

        expect(logger).to receive(:info).with('MockLog')
        config.logger.info 'MockLog'
      end
    end
  end
end
