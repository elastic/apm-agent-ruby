# frozen_string_literal: true

class EventCollector
  class TestAdapter < ElasticAPM::Transport::Connection
    def write(payload)
      EventCollector.catalog(JSON.parse(@metadata))
      EventCollector.catalog JSON.parse(payload)
    end
  end

  class << self
    def method_missing(name, *args, &block)
      if instance.respond_to?(name)
        instance.send(name, *args, &block)
      else
        super
      end
    end

    def instance
      @instance ||= new
    end
  end

  attr_reader(
    :errors,
    :metadatas,
    :metricsets,
    :requests,
    :spans,
    :transactions
  )

  def initialize
    @mutex = Mutex.new
    clear!
  end

  def catalog(json)
    @mutex.synchronize do
      case json.keys.first
      when 'transaction' then transactions << json.values.first
      when 'span' then spans << json.values.first
      when 'error' then errors << json.values.first
      when 'metricset' then metricsets << json.values.first
      when 'metadata' then metadatas << json.values.first
      end
    end
  end

  def clear!
    @requests = []

    @errors = []
    @metadatas = []
    @metricsets = []
    @spans = []
    @transactions = []
  end

  def transaction_metrics
    metrics = metricsets.select do |set|
      set && set['transaction'] && !set['span']
    end
    if metrics.empty?
      puts metricsets
    end
    metrics
  end

  def span_metrics
    metrics = metricsets.select do |set|
      set && set['transaction'] && set['span']
    end
    if metrics.empty?
      puts metricsets
    end
    metrics
  end

  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def wait_for(timeout: 5, **expected)
    if expected.empty? && !block_given?
      raise ArgumentError, 'Either args or block required'
    end

    Timeout.timeout(timeout) do
      loop do
        sleep 0.01

        missing = expected.reduce(0) do |total, (kind, count)|
          total + (count - send(kind).length)
        end

        next if missing > 0

        unless missing == 0
          if missing < 0
            puts format(
              'Expected %s. Got %s',
              expected,
              "#{missing.abs} extra"
            )
          else
            puts format(
              'Expected %s. Got %s',
              expected,
              "missing #{missing}"
            )
            print_received
          end
        end

        if block_given?
          next unless yield(self)
        end

        break true
      end
    end
  rescue Timeout::Error
    puts format('Died waiting for %s', block_given? ? 'block' : expected)
    puts '--- Received: ---'
    print_received
    raise
  end
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def metricsets_summary
    metricsets.each_with_object(
      Hash.new { 0 }
    ) do |set, totals|
      next unless set['transaction']

      samples = set['samples']

      if (count = samples['transaction.duration.count'])
        next totals[:transaction_durations] += count['value']
      end

      if (count = samples['transaction.breakdown.count'])
        next totals[:transaction_breakdowns] += count['value']
      end

      count = set['samples']['span.self_time.count']

      case set.dig('span', 'type')
      when 'app'
        subtype = set.dig('span', 'subtype')
        key = :"app_span_self_times__#{subtype || 'nil'}"
        next totals && totals[key] += count['value']
      when 'template'
        totals && totals[:template_span_self_times] += count['value']
        next
      else
        pp set
        raise 'Unmatched metric type'
      end
    end
  end
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  private

  def print_received
    pp(
      transactions: transactions.map { |o| o['name'] },
      spans: spans.map { |o| o['name'] },
      errors: errors.map { |o| o['culprit'] },
      metricsets: metricsets,
      metadatas: metadatas.count
    )
  end
end

RSpec.shared_context 'event_collector' do
  before do
    EventCollector.clear!
  end
  after do
    EventCollector.clear!
  end
end
