module RailsTestHelpers
  def self.included(_kls)
    Rails::Application.class_eval do
      def configure_rails_for_test
        config.secret_key_base = "__secret_key_base"
        config.consider_all_requests_local = false
        config.eager_load = false

        config.elastic_apm.api_request_time = "200ms"
        config.elastic_apm.disable_start_message = true

        return unless defined?(ActionView::Railtie::NULL_OPTION)

        # Silence deprecation warning
        config.action_view.finalize_compiled_template_methods = ActionView::Railtie::NULL_OPTION
      end
    end
  end

  def self.setup_rails_test_config(config)
    config.secret_key_base = "__secret_key_base"
    config.consider_all_requests_local = false
    config.eager_load = false

    if config.respond_to?(:action_mailer)
      config.action_mailer.perform_deliveries = false
    end

    config.logger = Logger.new(SpecLogger)

    # Silence deprecation warning
    return unless defined?(ActionView::Railtie::NULL_OPTION)
    config.action_view.finalize_compiled_template_methods = ActionView::Railtie::NULL_OPTION
  end
end

