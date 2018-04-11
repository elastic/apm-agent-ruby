# frozen_string_literal: true

module ElasticAPM
  # @api private
  class TimedWorker
    include Log

    SLEEP_INTERVAL = 0.1

    # @api private
    class StopMsg
    end

    # @api private
    class ErrorMsg
      def initialize(error)
        @error = error
      end

      attr_reader :error
    end

    def initialize(config, messages, pending_transactions, adapter)
      @config = config
      @messages = messages
      @pending_transactions = pending_transactions
      @adapter = adapter

      @last_sent_transactions = Time.now.utc

      @serializers = Struct.new(:transactions, :errors).new(
        Serializers::Transactions.new(config),
        Serializers::Errors.new(config)
      )
    end

    attr_reader :config, :messages, :pending_transactions

    def run_forever
      loop do
        run_once
        sleep SLEEP_INTERVAL
      end
    end

    def run_once
      collect_and_send_transactions if should_flush_transactions?
      process_messages
    end

    private

    # rubocop:disable Metrics/MethodLength
    def process_messages
      should_exit = false

      while (msg = messages.pop(true))
        case msg
        when ErrorMsg
          post_error msg
        when StopMsg
          should_exit = true

          # empty collected transactions before exiting
          collect_and_send_transactions
        end
      end
    rescue ThreadError # queue empty
      Thread.exit if should_exit
    end
    # rubocop:enable Metrics/MethodLength

    def post_error(msg)
      payload = @serializers.errors.build_all([msg.error])
      @adapter.post('/v1/errors', payload)
    end

    def collect_and_send_transactions
      return if pending_transactions.empty?

      transactions = collect_batched_transactions

      payload = @serializers.transactions.build_all(transactions)

      begin
        @adapter.post('/v1/transactions', payload)
      rescue ::Exception => e
        fatal 'Failed posting: %s', e.inspect
        debug e.backtrace.join("\n")
        nil
      end
    end

    def collect_batched_transactions
      batch = []

      begin
        while (transaction = pending_transactions.pop(true)) &&
              batch.length <= config.max_queue_size
          batch << transaction
        end
      rescue ThreadError # queue empty
      end

      batch
    end

    def should_flush_transactions?
      interval = config.flush_interval

      return true if interval.nil?
      return true if pending_transactions.length >= config.max_queue_size

      Time.now.utc - @last_sent_transactions >= interval
    end
  end
end
