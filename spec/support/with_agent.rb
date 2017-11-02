# frozen_string_literal: true

RSpec.configure do |config|
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
end
