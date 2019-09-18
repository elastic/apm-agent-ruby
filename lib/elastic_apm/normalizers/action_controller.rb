# frozen_string_literal: true

module ElasticAPM
  module Normalizers
    module ActionController
      # @api private
      class ProcessActionNormalizer < Normalizer
        register 'process_action.action_controller'

        TYPE = 'app'
        SUBTYPE = 'controller'
        ACTION = 'action'

        def normalize(transaction, _name, payload)
          transaction.name = endpoint(payload)
          [transaction.name, TYPE, SUBTYPE, ACTION, nil]
        end

        private

        def endpoint(payload)
          "#{payload[:controller]}##{payload[:action]}"
        end
      end
    end
  end
end
