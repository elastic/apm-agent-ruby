# Licensed to Elasticsearch B.V. under one or more contributor
# license agreements. See the NOTICE file distributed with
# this work for additional information regarding copyright
# ownership. Elasticsearch B.V. licenses this file to you under
# the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

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
        ['ELASTIC_APM_DISABLE_INSTRUMENTATIONS', 'json,http', %w[json http]],
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

    context 'server_url' do
      context 'as a String with a trailing slash' do
        subject { Config.new(server_url: 'http://localhost:8200/') }

        it 'strips the trailing slash' do
          expect(subject.server_url).to eq('http://localhost:8200')
        end
      end

      context 'as a URI with a trailing slash' do
        subject { Config.new(server_url: URI('http://localhost:8200/')) }

        it 'strips the trailing slash' do
          expect(subject.server_url).to eq('http://localhost:8200')
        end
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

    describe 'sample rate precision' do
      context 'sets a minimum' do
        subject { Config.new(transaction_sample_rate: '0.00001') }
        its(:transaction_sample_rate) { should eq 0.0001 }
      end
      context 'ensures max 4 digits of precision' do
        subject { Config.new(transaction_sample_rate: '0.55554') }
        its(:transaction_sample_rate) { should eq 0.5555 }
      end
    end

    it 'yields itself to a given block' do
      config = Config.new { |c| c.server_url = 'somewhere-else.com' }
      expect(config.server_url).to eq 'somewhere-else.com'
    end

    it 'has spies and may disable them' do
      expect(Config.new.available_instrumentations).to_not be_empty

      config = Config.new disable_instrumentations: ['json']
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

      it 'overrides the logger if given a log_path' do
        Tempfile.open 'elastic-apm' do |file|
          logger = double(Logger)
          config = Config.new logger: logger, log_path: file.path
          config.logger.info 'This test ran'
          expect(file.read).to match(/This test ran$/)
        end
      end

      describe 'log level' do
        it 'can accept integers' do
          config = Config.new log_level: Logger::FATAL
          expect(config.log_level).to eq(Logger::FATAL)
        end

        it 'can accept symbols' do
          config = Config.new log_level: :fatal
          expect(config.log_level).to eq(Logger::FATAL)
        end

        it 'can accept symbols not mapping to native Ruby logger levels' do
          config = Config.new log_level: :critical
          expect(config.log_level).to eq(Logger::FATAL)
        end
      end

      describe 'ecs logging' do
        context "when old config option is used, with 'override'" do
          it 'builds an EcsLogging::Logger' do
            config = Config.new log_ecs_formatting: 'override'
            expect(config.logger).to be_a(::EcsLogging::Logger)
          end
        end

        context "when log_ecs_reformatting is 'override'" do
          it 'builds an EcsLogging::Logger' do
            config = Config.new log_ecs_reformatting: 'override'
            expect(config.logger).to be_a(::EcsLogging::Logger)
          end
        end

        context "when the log_ecs_reformatting value is not valid" do
          it 'builds a ::Logger' do
            config = Config.new log_ecs_reformatting: 'invalid_option'
            # Using be_a(::Logger) would be true even if the logger were
            # a EcsLogging::Logger because the class inherits from ::Logger.
            # So we test the negative:
            expect(config.logger).not_to be_a(::EcsLogging::Logger)
          end
        end
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

    context 'boolean values' do
      subject { Config.new }

      it 'allows false to be set' do
        subject.capture_headers = false
        expect(subject.capture_headers).to eq(false)
        expect(subject.capture_headers?).to eq(false)
      end
    end

    describe '#replace_options' do
      subject { Config.new(server_url: 'somewhere-else.com') }

      it 'replaces the option values' do
        subject.replace_options(api_request_time: '1s', api_buffer_size: 100)
        expect(subject.api_request_time).to eq(1)
        expect(subject.api_buffer_size).to eq(100)
      end

      it 'leaves existing config values unchanged' do
        subject.replace_options(api_request_time: '1s')
        expect(subject.server_url).to eq('somewhere-else.com')
      end

      it 'replaces the options object' do
        original_options = subject.options
        subject.replace_options(api_request_time: '1s')
        expect(subject.options).not_to be(original_options)
      end

      it 'does not update the log level on the existing logger' do
        subject.replace_options(log_level: Logger::DEBUG)
        expect(subject.logger.level).to eq(Logger::INFO)
      end
    end

    describe "#version" do
      it "has no version if the server does not respond" do
        WebMock.stub_request(:get, "http://localhost:8200/")
          .to_return(status: 404, body: "")
        expect(Config.new.version).to be_nil
      end

      it "returns the version from the server" do
        WebMock.stub_request(:get, "http://localhost:8200/")
          .to_return(status: 200, body: '{"version": 8.0}')
        expect(Config.new.version).to eq 8.0
      end
    end
  end
end
