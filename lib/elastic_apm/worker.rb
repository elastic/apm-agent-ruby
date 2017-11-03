# frozen_string_literal: true

module ElasticAPM
  # @api private
  class Worker
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

    def run_forever
      loop do
        while (item = @queue.pop)
          case item
          when Request
            @adapter.post(item.path, item.payload)
          when StopMessage
            Thread.exit
          end
        end
      end
    end
  end
end
