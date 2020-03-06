# frozen_string_literal: true

module ElasticAPM
  # Defines a before_first_fork hook for starting the ElasticAPM agent
  # with Resque.
  module Resque
    ::Resque.before_first_fork do
      ::Resque.logger.debug('Starting ElasticAPM agent')
      ElasticAPM.start
    end
  end
end
