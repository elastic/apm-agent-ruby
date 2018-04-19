# frozen_string_literal: true

module ElasticAPM
  module Normalizers
    module ActionMailer
      # @api private
      class ProcessActionNormalizer < Normalizer
        register 'process.action_mailer'
        TYPE = 'app.mailer.action'.freeze

        def normalize(transaction, _name, payload)
          transaction.name = endpoint(payload)
          [transaction.name, TYPE, nil]
        end

        private

        def endpoint(payload)
          "#{payload[:mailer]}##{payload[:action]}"
        end
      end
    end
  end
end
