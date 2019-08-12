# frozen_string_literal: true

require 'elastic_apm/central_config/cache_control'

module ElasticAPM
  # @api private
  class CentralConfig
    include Logging

    # @api private
    class ResponseError < InternalError
      def initialize(response)
        @response = response
      end

      attr_reader :response
    end
    class ClientError < ResponseError; end
    class ServerError < ResponseError; end

    DEFAULT_MAX_AGE = 300

    def initialize(config)
      @config = config
      @modified_options = {}
      @service_info = {
        'service.name': config.service_name,
        'service.environment': config.environment
      }.to_json
    end

    attr_reader :config, :task

    def start
      return unless config.central_config?

      fetch_and_apply_config
    end

    def fetch_and_apply_config
      Concurrent::Promise
        .execute(&method(:fetch_config))
        .on_success(&method(:handle_success))
        .rescue(&method(:handle_error))
    end

    def stop
      @task&.cancel
    end

    # rubocop:disable Metrics/MethodLength
    def fetch_config
      resp = perform_request

      case resp.status
      when 200..299
        resp
      when 300..399
        resp
      when 400..499
        raise ClientError, resp
      when 500..599
        raise ServerError, resp
      end
    end
    # rubocop:enable Metrics/MethodLength

    def assign(update)
      # For each updated option, store the original value,
      # unless already stored
      update.each_key do |key|
        @modified_options[key] ||= config.get(key.to_sym)&.value
      end

      # If the new update doesn't set a previously modified option,
      # revert it to the original
      @modified_options.each_key do |key|
        next if update.key?(key)
        update[key] = @modified_options.delete(key)
      end

      config.assign(update)
    end

    private

    def handle_success(resp)
      # 304 Not Modified
      unless resp.status == 304
        update = JSON.parse(resp.body.to_s)
        assign(update)
      end

      info 'Updated config from APM Server'

      schedule_next_fetch(resp)

      true
    rescue Exception => e
      error 'Failed to apply remote config, %s', e.inspect
      debug { e.backtrace.join('\n') }
    end

    def handle_error(error)
      error(
        'Failed fetching config: %s, trying again in %d seconds',
        error.response.body, DEFAULT_MAX_AGE
      )

      assign({})

      schedule_next_fetch(error.response)
    end

    def perform_request
      Http.post(
        config.server_url + '/agent/v1/config/',
        body: @service_info,
        headers: { etag: 1, content_type: 'application/json' }
      )
    end

    def schedule_next_fetch(resp)
      seconds =
        if (cache_header = resp.headers['Cache-Control'])
          CacheControl.new(cache_header).max_age
        else
          DEFAULT_MAX_AGE
        end

      @task =
        Concurrent::ScheduledTask
        .execute(seconds, &method(:fetch_and_apply_config))
    end
  end
end
