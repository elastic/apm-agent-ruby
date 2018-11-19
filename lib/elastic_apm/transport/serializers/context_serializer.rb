# frozen_string_literal: true

module ElasticAPM
  module Transport
    module Serializers
      # @api private
      class ContextSerializer < Serializer
        def build(context)
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
            url: request.url
          }
        end
        # rubocop:enable Metrics/MethodLength

        def build_response(response)
          return unless response

          {
            status_code: response.status_code,
            headers: response.headers,
            headers_sent: response.headers_sent,
            finished: response.finished
          }
        end

        def build_user(user)
          return unless user

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
      end
    end
  end
end
