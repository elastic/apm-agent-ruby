# frozen_string_literal: true

module ElasticAPM
  # @api private
  class Context
    # @api private
    class Request
      # @api private
      class ApplyRackEnv
        class << self
          def call(request, rack_env)
            req = rails_req?(rack_env) ? rack_env : Rack::Request.new(rack_env)

            request.socket = Socket.new(req).to_h
            request.http_version = build_http_version rack_env
            request.method = req.request_method
            request.url = Url.new(req).to_h
            request.headers, request.env = get_headers_and_env(rack_env)
            request.body = get_body(req)

            request
          end

          private

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
    end
  end
end
