# frozen_string_literal: true

require 'bundler/setup'
Bundler.require :default
require 'support/delegate_matcher'

require 'elastic_apm'

RSpec.configure do |config|
  config.example_status_persistence_file_path = '.rspec_status'
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.around :each, with_agent: true do |example|
    ElasticAPM.start ElasticAPM::Config.new

    begin
      example.run
    ensure
      # be sure not to bleed transaction onto next example
      ElasticAPM.agent.current_transaction&.release
      ElasticAPM.stop
    end
  end

  config.around :each, mock_time: true do |example|
    @date = Time.utc(1992, 1, 1)

    def travel(distance)
      Timecop.freeze(@date += distance / 1_000.0)
    end

    travel 0
    example.run
    Timecop.return
  end
end
