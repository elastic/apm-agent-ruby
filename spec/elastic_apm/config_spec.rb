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

    it 'loads from config file' do
      config = Config.new(config_file: 'spec/fixtures/elastic_apm.yml')
      expect(config.server_url).to eq 'somewhere-config.com'
    end

    it 'loads from erb-styled config file' do
      config = Config.new(config_file: 'spec/fixtures/elastic_apm_erb.yml')
      expect(config.server_url).to eq 'somewhere-config.com'
    end

    it 'takes options from ENV' do
      with_env('ELASTIC_APM_SERVER_URL' => 'by-env!') do
        expect(Config.new.server_url).to eq 'by-env!'
      end
    end

    it 'raises an exception when *_DEFAULT_LABELS and *_DEFAULT_TAGS are set' do
      # As soon as we build a config with default_tags, `warn' will be called.
      # This makes sure we don't pollute the test output.
      allow_any_instance_of(Config).to receive(:warn)
        .with(/default_tags=.*removed./)
      with_env('ELASTIC_APM_DEFAULT_TAGS' => 'wave=something',
               'ELASTIC_APM_DEFAULT_LABELS' => 'brother=ok') do
        expect {
          Config.new.default_labels
        }.to raise_exception(Exception, Config::LABELS_AND_TAGS_CONFLICT)
      end
    end

    it 'converts certain env values to Ruby types' do
      allow_any_instance_of(Config).to receive(:warn)
        .with(/default_tags=.*removed./)
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
        ['ELASTIC_APM_DISABLED_INSTRUMENTATIONS', 'json,http', %w[json http]],
        ['ELASTIC_APM_CUSTOM_KEY_FILTERS', 'Auth,Other', [/Auth/, /Other/]],
        [
          'ELASTIC_APM_DEFAULT_TAGS',
          'test=something something&other=ok',
          { 'test' => 'something something', 'other' => 'ok' }
        ],
        [
          'ELASTIC_APM_DEFAULT_LABELS',
          'wave=something erlking&brother=ok',
          { 'wave' => 'something erlking', 'brother' => 'ok' }
        ],
        [
          'ELASTIC_APM_GLOBAL_LABELS',
          'why=hello goodbye,apples=oranges',
          { 'why' => 'hello goodbye', 'apples' => 'oranges' }
        ]
      ].each do |(key, val, expected)|
        with_env(key => val) do
          setting = key.gsub('ELASTIC_APM_', '').downcase
          expect(Config.new.send(setting.to_sym)).to eq expected
        end
      end
    end

    it 'can get config_file specified by env' do
      with_env('ELASTIC_APM_CONFIG_FILE' => 'spec/fixtures/elastic_apm.yml') do
        config = Config.new
        expect(config.config_file).to eq('spec/fixtures/elastic_apm.yml')
        expect(config.server_url).to eq('somewhere-config.com')
      end
    end

    context 'duration units' do
      subject do
        Config.new(
          api_request_time: '1m',
          span_frames_min_duration: '10ms'
        )
      end

      its(:api_request_time) { should eq 60 }
      its(:span_frames_min_duration) { should eq 0.010 }

      context 'when no unit' do
        it 'uses default unit' do
          expect(Config.new(api_request_time: '4').api_request_time).to eq 4
          expect(
            Config.new(span_frames_min_duration: '5').span_frames_min_duration
          ).to eq 0.005
        end
      end
    end

    describe 'byte units' do
      context 'with a unit' do
        subject { Config.new(api_request_size: '500kb') }
        its(:api_request_size) { should eq 500 * 1024 }
      end
      context 'without a unit' do
        subject { Config.new(api_request_size: '1') }
        its(:api_request_size) { should eq 1024 }
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
      expect(Config.new.available_instrumentations).to_not be_empty

      config = Config.new disabled_instrumentations: ['json']
      expect(config.enabled_instrumentations).to_not include('json')
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

    describe 'unknown options' do
      it 'warns' do
        expect(subject).to receive(:warn).with(/Unknown option/)
        subject.unknown_option = 'whatever'
      end

      context 'from args' do
        it 'warns' do
          expect_any_instance_of(Config)
            .to receive(:warn).with(/Unknown option/)
          Config.new(unknown_key: true)
        end
      end

      context 'from config_file' do
        it 'warns' do
          expect_any_instance_of(Config)
            .to receive(:warn).with(/Unknown option/)
          Config.new(config_file: 'spec/fixtures/unknown_option.yml')
        end
      end
    end
  end
end
