require 'spec_helper'

RSpec.configure do |config|
  config.before(:each) do |example|
    if ElasticAPM.running? && !example.metadata[:allow_running_agent]
      raise "Previous example left an agent running"
    end
  end

  config.after(:each) do |example|
    if ElasticAPM.running? && !example.metadata[:allow_running_agent]
      raise "This example left an agent running"
    end
  end

  config.after(:each, spec_logger: true) do |example|
    SpecLogger.rewind
    next unless example.exception

    puts("Example failed, dumping log:")
    puts(SpecLogger.read)
  end
end
