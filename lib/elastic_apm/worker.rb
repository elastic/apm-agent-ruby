# frozen_string_literal: true

require 'concurrent/timer_task'

module ElasticAPM
  # @api private
  class Worker
    include Log

    # @api private
    class StopMsg; end

    # @api private
    class FlushMsg; end

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

      @serializers = Struct.new(:transactions, :errors).new(
        Serializers::Transactions.new(config),
        Serializers::Errors.new(config)
      )
    end

    attr_reader :config, :messages, :pending_transactions

    # rubocop:disable Metrics/MethodLength
    def run_forever
      @timer_task = build_timer_task.execute

      while (msg = messages.pop)
        case msg
        when ErrorMsg
          post_error msg
        when FlushMsg
          collect_and_send_transactions
        when StopMsg
          # empty collected transactions before exiting
          collect_and_send_transactions
          stop!
        end
      end
    end
    # rubocop:enable Metrics/MethodLength

    private

    def stop!
      @timer_task && @timer_task.shutdown
      Thread.exit
    end

    def build_timer_task
      Concurrent::TimerTask.new(execution_interval: config.flush_interval) do
        messages.push(FlushMsg.new)
      end
    end

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
  end
end
