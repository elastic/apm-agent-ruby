# frozen_string_literal: true

module ElasticAPM
  # @api private
  class ErrorBuilder
    MOD_SPLIT = '::'

    def initialize(config)
      @config = config
    end

    def build(exception, rack_env: nil, handled: true)
      error = Error.new

      attach_exception error, exception, handled: handled
      attach_rack_env error, rack_env if rack_env

      error
    end

    def attach_exception(error, original_exception, handled: true)
      exception = Error::Exception.new(
        "#{original_exception.class}: #{original_exception.message}",
        original_exception.class.to_s,
        handled: handled
      )
      exception.module = format_module original_exception

      add_stacktrace error, exception, original_exception
      error.exception = exception
    end

    def add_stacktrace(error, exception, original_exception)
      stacktrace = Stacktrace.build(@builder, original_exception)
      return unless stacktrace

      exception.stacktrace = stacktrace
      error.culprit = stacktrace.culprit
    end

    def attach_rack_env(error, rack_env)
      error.context.request = build_request(rack_env)
      error
    end

    private

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def build_request(rack_env)
      req = rails_req?(rack_env) ? rack_env : Rack::Request.new(rack_env)

      request = Error::Context::Request.new

      request.socket = {
        remote_address: req.ip,
        encrypted: req.scheme == 'https'
      }
      request.http_version = rack_env['HTTP_VERSION']&.gsub(%r{HTTP/}, nil)
      request.method = req.request_method
      request.url = {
        protocol: req.scheme,
        hostname: req.host,
        port: req.port,
        pathname: req.path,
        search: req.query_string,
        hash: nil,
        raw: req.fullpath
      }

      add_headers_to_request(request, rack_env)
      add_body_to_request(request, req)

      request
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    def add_body_to_request(request, req)
      if req.form_data?
        request.body = req.POST
      else
        request.body = req.body.read
        req.body.rewind
      end
    end

    def format_module(exception)
      exception.class.to_s.split(MOD_SPLIT)[0...-1].join(MOD_SPLIT)
    end

    def rails_req?(env)
      defined?(ActionDispatch::Request) && env.is_a?(ActionDispatch::Request)
    end

    def add_headers_to_request(request, rack_env)
      get_headers(rack_env).each do |key, value|
        next unless key.upcase == key

        if key.start_with?('HTTP_')
          request.headers[camel_key(key)] = value
        else
          request.env[key] = value
        end
      end
    end

    def camel_key(key)
      key.gsub(/^HTTP_/, '').split('_').map(&:capitalize).join('-')
    end

    def get_headers(rack_env)
      # In Rails < 5 ActionDispatch::Request inherits from Hash
      rack_env.respond_to?(:headers) ? rack_env.headers : rack_env
    end
  end
end
