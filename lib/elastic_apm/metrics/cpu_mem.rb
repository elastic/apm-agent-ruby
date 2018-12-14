# frozen_string_literal: true

module ElasticAPM
  class Metrics
    # @api private
    class CpuMem
      include Logging

      # @api private
      class Sample
        # rubocop:disable Metrics/ParameterLists
        def initialize(
          system_cpu_total:,
          system_cpu_usage:,
          system_memory_total:,
          system_memory_free:,
          process_cpu_usage:,
          process_memory_size:,
          process_memory_rss:,
          page_size:
        )
          @system_cpu_total = system_cpu_total
          @system_cpu_usage = system_cpu_usage
          @system_memory_total = system_memory_total
          @system_memory_free = system_memory_free
          @process_cpu_usage = process_cpu_usage
          @process_memory_size = process_memory_size
          @process_memory_rss = process_memory_rss
          @page_size = page_size
        end
        # rubocop:enable Metrics/ParameterLists

        attr_accessor :system_cpu_total, :system_cpu_usage,
          :system_memory_total, :system_memory_free, :process_cpu_usage,
          :process_memory_size, :process_memory_rss, :page_size

        def delta(previous)
          dup.tap do |sample|
            sample.system_cpu_total =
              system_cpu_total - previous.system_cpu_total
            sample.system_cpu_usage =
              system_cpu_usage - previous.system_cpu_usage
            sample.process_cpu_usage =
              process_cpu_usage - previous.process_cpu_usage
          end
        end
      end

      def initialize(config)
        @config = config
        @sampler = sampler_for_platform(Metrics.platform)
      end

      attr_reader :config, :sampler

      def sample
        @sampler.sample
      end

      # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      def collect
        return unless sampler

        current = sample

        unless @previous
          @previous = current
          return
        end

        delta = current.delta(@previous)

        cpu_usage_pct = delta.system_cpu_usage.to_f / delta.system_cpu_total
        cpu_process_pct = delta.process_cpu_usage.to_f / delta.system_cpu_total

        {
          'system.cpu.total.norm.pct': cpu_usage_pct,
          'system.memory.actual.free': current.system_memory_free,
          'system.memory.total': current.system_memory_total,
          'system.process.cpu.total.norm.pct': cpu_process_pct,
          'system.process.memory.size': current.process_memory_size,
          'system.process.memory.rss.bytes':
            current.process_memory_rss * current.page_size
        }
      end
      # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

      private

      def sampler_for_platform(platform)
        case platform
        when :linux then Linux.new
        else
          warn "Unsupported platform '#{platform}' - Disabling metrics"
          @disabled = true
          nil
        end
      end

      # @api private
      class Linux
        # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
        def sample
          proc_stat = ProcStat.new.read!
          proc_self_stat = ProcSelfStat.new.read!
          meminfo = Meminfo.new.read!

          Sample.new(
            system_cpu_total: proc_stat.total,
            system_cpu_usage: proc_stat.usage,
            system_memory_total: meminfo.total,
            system_memory_free: meminfo.available,
            process_cpu_usage: proc_self_stat.total,
            process_memory_size: proc_self_stat.vsize,
            process_memory_rss: proc_self_stat.rss,
            page_size: meminfo.page_size
          )
        end
        # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

        # @api private
        class ProcStat
          attr_reader :total, :usage

          # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
          def read!
            stat =
              IO.readlines('/proc/stat')
                .lazy
                .find { |sp| sp.start_with?('cpu ') }
                .split
                .map(&:to_i)[1..-1]

            user, nice, system, idle, iowait, irq, softirq, steal,
              _guest, _guest_nice = stat

            @total =
              user +
              nice +
              system +
              idle +
              iowait +
              irq +
              softirq +
              steal

            @usage = @total - idle + iowait

            self
          end
          # rubocop:enable Metrics/MethodLength, Metrics/AbcSize
        end

        # @api private
        class ProcSelfStat
          attr_reader :total, :vsize, :rss

          def read!
            stat =
              IO.readlines('/proc/self/stat')
                .lazy
                .first
                .split
                .map(&:to_i)

            @total = stat[13] + stat[14] # utime + stime
            @vsize = stat[22]
            @rss = stat[23]

            self
          end
        end

        # @api private
        class Meminfo
          attr_reader :total, :available, :page_size

          # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
          def read!
            # rubocop:disable Style/RescueModifier
            @page_size = `getconf PAGESIZE`.chomp.to_i rescue 4096
            # rubocop:enable Style/RescueModifier

            info =
              IO.readlines('/proc/meminfo')
                .lazy
                .each_with_object({}) do |line, hsh|
                  if line.start_with?('MemTotal:')
                    hsh[:total] = line.split[1].to_i * 1024
                  elsif line.start_with?('MemAvailable:')
                    hsh[:available] = line.split[1].to_i * 1024
                  end

                  break hsh if hsh.length == 2
                end

            @total = info[:total]
            @available = info[:available]

            self
          end
          # rubocop:enable Metrics/MethodLength, Metrics/AbcSize
        end
      end
    end
  end
end
