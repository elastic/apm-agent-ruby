# frozen_string_literal: true

module ElasticAPM
  class Error
    # @api private
    class Context
      # @api private
      class Request
        SKIPPED_PORTS = {
          'http' => 80,
          'https' => 443
        }.freeze

        def initialize
          @socket = {}
          @headers = {}
          @cookies = {}
          @env = {}
        end

        attr_accessor :body, :cookies, :env, :headers, :http_version, :method,
          :socket, :url

        # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        def add_rack_env(rack_env)
          req = rails_req?(rack_env) ? rack_env : Rack::Request.new(rack_env)

          self.socket = {
            remote_address: req.ip,
            encrypted: req.scheme == 'https'
          }
          http_version = rack_env['HTTP_VERSION']
          self.http_version =
            http_version && http_version.gsub(%r{HTTP/}, '')
          self.method = req.request_method
          self.url = {
            protocol: req.scheme,
            hostname: req.host,
            port: req.port,
            pathname: req.path,
            search: req.query_string,
            hash: nil,
            full: build_full_url(req)
          }

          add_headers(rack_env)
          add_body(req)

          self
        end
        # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

        def self.from_rack_env(rack_env)
          request = new
          request.add_rack_env rack_env
          request
        end

        private

        def add_body(req)
          if req.form_data?
            self.body = req.POST
          else
            self.body = req.body.read
            req.body.rewind
          end
        end

        def rails_req?(env)
          defined?(ActionDispatch::Request) &&
            env.is_a?(ActionDispatch::Request)
        end

        def add_headers(rack_env)
          get_headers(rack_env).each do |key, value|
            next unless key.upcase == key

            if key.start_with?('HTTP_')
              headers[camel_key(key)] = value
            else
              env[key] = value
            end
          end
        end

        def camel_key(key)
          key.gsub(/^HTTP_/, '').split('_').map(&:capitalize).join('-')
        end

        def build_full_url(req)
          url = "#{req.scheme}://#{req.host}"

          if req.port != SKIPPED_PORTS[req.scheme]
            url += ":#{req.port}"
          end

          url + req.fullpath
        end

        def get_headers(rack_env)
          # In Rails < 5 ActionDispatch::Request inherits from Hash
          rack_env.respond_to?(:headers) ? rack_env.headers : rack_env
        end
      end

      # @api private
      class Response
        attr_accessor(
          :status_code,
          :headers,
          :headers_sent,
          :finished
        )
      end

      attr_accessor(
        :request,
        :response,
        :user,
        :tags,
        :custom
      )
    end
  end
end
