# frozen_string_literal: true

require 'concurrent'

module ElasticAPM
  module Transport
    # @api private
    class Connection
      # @api private
      class State
        STATES = {
          disconnected: 0,
          connecting: 1,
          connected: 2
        }.freeze

        def initialize(value: STATES[:disconnected])
          @atom = Concurrent::AtomicFixnum.new(value)
        end

        def value=(value)
          @atom.value = value
        end

        def value
          @atom.value
        end

        STATES.each do |key, value|
          define_method(:"#{key}!") { self.value = value }
          define_method(:"#{key}?") { self.value == value }
        end

        def inspect
          "<#{self.class} #{STATES.key(@atom.value)}>"
        end
      end
    end
  end
end
