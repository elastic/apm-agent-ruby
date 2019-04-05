# frozen_string_literal: true

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

        def hold
          @atom.update do
            yield self
            nil
          end
        end

        def disconnected!
          self.value = STATES[:disconnected]
        end

        def disconnected?
          value == STATES[:disconnected]
        end

        def connecting!
          self.value = STATES[:connecting]
        end

        def connecting?
          value == STATES[:connecting]
        end

        def connected!
          self.value = STATES[:connected]
        end

        def connected?
          value == STATES[:connected]
        end

        def inspect
          "<#{self.class} #{STATES.key(@atom.value)}>"
        end
      end
    end
  end
end
