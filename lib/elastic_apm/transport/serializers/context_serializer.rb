# frozen_string_literal: true

module ElasticAPM
  module Transport
    module Serializers
      # @api private
      class ContextSerializer < Serializer
        def build(context)
          return nil if context.nil? || context.empty?

          {
            custom: context.custom,
            tags: keyword_object(context.tags),
            request: build_request(context.request),
            response: build_response(context.response),
            user: build_user(context.user)
          }
        end

        private

        # rubocop:disable Metrics/MethodLength
        def build_request(request)
          return unless request

          {
            body: request.body,
            cookies: request.cookies,
            env: request.env,
            headers: request.headers,
            http_version: keyword_field(request.http_version),
            method: keyword_field(request.method),
            socket: build_socket(request.socket),
            url: build_url(request.url)
          }
        end
        # rubocop:enable Metrics/MethodLength

        def build_response(response)
          return unless response

          {
            status_code: response.status_code.to_i,
            headers: response.headers,
            headers_sent: response.headers_sent,
            finished: response.finished
          }
        end

        def build_user(user)
          return if !user || user.empty?

          {
            id: keyword_field(user.id),
            email: keyword_field(user.email),
            username: keyword_field(user.username)
          }
        end

        def build_socket(socket)
          return unless socket

          {
            remote_addr: socket.remote_addr,
            encrypted: socket.encrypted
          }
        end

        def build_url(url)
          return unless url

          {
            protocol: keyword_field(url.protocol),
            full: keyword_field(url.full),
            hostname: keyword_field(url.hostname),
            port: keyword_field(url.port),
            pathname: keyword_field(url.pathname),
            search: keyword_field(url.search),
            hash: keyword_field(url.hash)
          }
        end
      end
    end
  end
end
