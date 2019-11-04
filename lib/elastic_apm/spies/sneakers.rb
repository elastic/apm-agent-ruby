# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Spies
    # @api private
    class SneakersSpy
      include Logging

      def install
        # sneakers 2.12.0 introduced middleware concept and the spy needs that
        if Gem.loaded_specs["sneakers"].version < Gem::Version.create("2.12.0")
          warn("Sneakers version is below 2.12.0. Sneakers spy installation failed")
        else
          Sneakers.middleware.use(Middleware, nil)
        end
      end
      # @api private
      class Middleware
        def initialize(app, *args)
          @app = app
          @args = args
        end

        def call(deserialized_msg, delivery_info, metadata, handler)
          transaction = ElasticAPM.start_transaction(delivery_info.consumer.queue.name, 'Sneakers')
          ElasticAPM.set_label(:routing_key, delivery_info.routing_key)
          res = @app.call(deserialized_msg, delivery_info, metadata, handler)
          transaction.done :success if transaction
          res
        rescue ::Exception => e
          ElasticAPM.report(e, handled: false)
          transaction.done :error if transaction
          raise
        ensure
          ElasticAPM.end_transaction
        end
      end
    end
    register 'Sneakers', 'sneakers', SneakersSpy.new
  end
end
