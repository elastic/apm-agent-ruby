# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Spies
    # @api private
    class SneakersSpy
      include Logging

      def self.supported_version?
        Gem.loaded_specs['sneakers'].version >= Gem::Version.create('2.12.0')
      end

      def install
        unless SneakersSpy.supported_version?
          warn(
            'Sneakers version is below 2.12.0. Sneakers spy installation failed'
          )
          return
        end

        Sneakers.middleware.use(Middleware, nil)
      end

      # @api private
      class Middleware
        def initialize(app, *args)
          @app = app
          @args = args
        end

        def call(deserialized_msg, delivery_info, metadata, handler)
          transaction =
            ElasticAPM.start_transaction(
              delivery_info.consumer.queue.name,
              'Sneakers'
            )

          ElasticAPM.set_label(:routing_key, delivery_info.routing_key)

          res = @app.call(deserialized_msg, delivery_info, metadata, handler)
          transaction&.done(:success)

          res
        rescue ::Exception => e
          ElasticAPM.report(e, handled: false)
          transaction&.done(:error)
          raise
        ensure
          ElasticAPM.end_transaction
        end
      end
    end

    register 'Sneakers', 'sneakers', SneakersSpy.new
  end
end
