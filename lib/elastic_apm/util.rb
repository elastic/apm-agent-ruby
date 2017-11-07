# frozen_string_literal: true

module ElasticAPM
  # @api private
  class Util
    def self.nearest_minute(target = Time.now.utc)
      target - target.to_i % 60
    end

    def self.nanos(target = Time.now.utc)
      target.to_i * 1_000_000_000 + target.usec * 1_000
    end

    def self.inspect_transaction(transaction)
      Inspector.new.transaction transaction
    end
  end

  # @api private
  class Inspector
    include Log

    DEFAULTS = {
      width: 120
    }.freeze

    SPACE = ' '

    def initialize(config = {})
      @config = config.reverse_merge(DEFAULTS)
    end

    def ms(nanos)
      nanos.to_f / 1_000_000
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def transaction(transaction, opts = {})
      w = @config[:width].to_f
      f = w / ms(transaction.duration)

      traces = transaction.traces

      traces = traces.each_with_object([]) do |trace, state|
        descriptions = [
          "#{trace.name} - #{trace.type}",
          "transaction:#{transaction.name}"
        ]

        if opts[:include_parents]
          descriptions << "parents:#{trace.parents.map(&:name).join(',')}"
        end

        descriptions <<
          "duration:#{ms trace.duration}ms - rel:#{ms trace.relative_start}ms"

        start_diff = ms(trace.start_time) - ms(transaction.start_time)
        indent = (start_diff.floor * f).to_i

        longest_desc_length = descriptions.map(&:length).max
        desc_indent = [[indent, w - longest_desc_length].min, 0].max

        lines = descriptions.map do |desc|
          "#{SPACE * desc_indent}#{desc}"
        end

        if trace.duration
          span = (ms(trace.duration) * f).ceil.to_i
          lines << "#{SPACE * indent}+#{'-' * [(span - 2), 0].max}+"
        else
          lines << "#{SPACE * indent}UNFINISHED"
        end

        state << lines.join("\n")
      end.join("\n")

      <<-STR.gsub(/^\s{6}/, '')
      \n#{'=' * w.to_i}
      #{transaction.name} - type:#{transaction.type} - #{transaction.duration.to_f / 1_000_000}ms
      +#{'-' * (w.to_i - 2)}+
        #{traces}
        STR
    rescue StandardError => e
      debug e
      debug e.backtrace.join("\n")
      transaction.inspect
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
  end
end
