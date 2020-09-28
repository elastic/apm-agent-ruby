SpecLogger = StringIO.new

module RailsTestHelpers
  def self.setup_rails_test_config(config)
    config.secret_key_base = "__secret_key_base"
    config.consider_all_requests_local = false
    config.eager_load = false

    config.elastic_apm.api_request_time = "200ms"
    config.elastic_apm.disable_start_message = true

    if config.respond_to?(:action_mailer)
      config.action_mailer.perform_deliveries = false
    end

    config.logger = Logger.new(SpecLogger)
  end
end

