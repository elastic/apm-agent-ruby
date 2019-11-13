# frozen_string_literal: true

module ElasticAPM
  module Normalizers
    module ActionMailer
      # @api private
      class ProcessActionNormalizer < Normalizer
        register 'process.action_mailer'

        TYPE = 'app'
        SUBTYPE = 'mailer'
        ACTION = 'action'

        def normalize(_transaction, _name, payload)
          [endpoint(payload), TYPE, SUBTYPE, ACTION, nil]
        end

        private

        def endpoint(payload)
          "#{payload[:mailer]}##{payload[:action]}"
        end
      end
    end
  end
end
