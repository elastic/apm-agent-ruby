# frozen_string_literal: true

module ElasticAPM
  class InternalError < StandardError; end
  class ExistingTransactionError < InternalError; end
end
