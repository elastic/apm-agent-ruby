# frozen_string_literal: true

module ElasticAPM
  # @api private
  class ContextBuilder
    CONTROLLER_KEY = 'action_controller.instance'.freeze

    def initialize(config)
      @config = config
    end

    attr_reader :config

    def build(rack_env)
      context = Context.new

      apply_to_request(context, rack_env)
      apply_to_user(context, rack_env)

      context
    end

    private

    # rubocop:disable Metrics/AbcSize
    def apply_to_request(context, rack_env)
      req = rails_req?(rack_env) ? rack_env : Rack::Request.new(rack_env)

      context.request = Context::Request.new unless context.request
      request = context.request

      request.socket = Context::Request::Socket.new(req).to_h
      request.http_version = build_http_version rack_env
      request.method = req.request_method
      request.url = Context::Request::Url.new(req).to_h
      request.headers, request.env = get_headers_and_env(rack_env)
      request.body = get_body(req)

      context
    end
    # rubocop:enable Metrics/AbcSize

    def apply_to_user(context, rack_env)
      return unless (controller = rack_env[CONTROLLER_KEY])

      method = config.current_user_method.to_sym
      return unless controller.respond_to?(method)

      return unless (record = controller.send method)

      context.user = Context::User.new(config, record)
      context
    end

    def get_body(req)
      return req.POST if req.form_data?

      body = req.body.read
      req.body.rewind
      body
    end

    def rails_req?(env)
      defined?(ActionDispatch::Request) &&
        env.is_a?(ActionDispatch::Request)
    end

    def get_headers_and_env(rack_env)
      # In Rails < 5 ActionDispatch::Request inherits from Hash
      headers =
        rack_env.respond_to?(:headers) ? rack_env.headers : rack_env

      headers.each_with_object([{}, {}]) do |(key, value), (http, env)|
        next unless key == key.upcase

        if key.start_with?('HTTP_')
          http[camel_key(key)] = value
        else
          env[key] = value
        end
      end
    end

    def camel_key(key)
      key.gsub(/^HTTP_/, '').split('_').map(&:capitalize).join('-')
    end

    def build_http_version(rack_env)
      return unless (http_version = rack_env['HTTP_VERSION'])
      http_version.gsub(%r{HTTP/}, '')
    end
  end
end
