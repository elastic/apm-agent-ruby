# frozen_string_literal: true

module ElasticAPM
  # @api private
  class Worker
    include Log

    # @api private
    class StopMessage; end

    # @api private
    Request = Struct.new(:path, :payload) do
      # require all params
      def initialize(path, payload)
        super
      end
    end

    def initialize(config, queue, http: Http)
      @config = config
      @adapter = http.new(config)
      @queue = queue
    end

    attr_reader :config

    def run_forever
      loop do
        while (item = @queue.pop)
          case item
          when Request
            process item
          when StopMessage
            Thread.exit
          end
        end
      end
    end

    def process(item)
      @adapter.post(item.path, item.payload)
    rescue ::Exception => e
      fatal "Failed posting: #{e.inspect}"
      debug e.backtrace.join("\n")
      nil
    end
  end
end
