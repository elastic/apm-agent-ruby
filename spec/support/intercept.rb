# frozen_string_literal: true

RSpec.configure do |config|
  class Intercept
    def initialize
      @transactions = []
      @spans = []
      @errors = []
      @metricsets = []
    end

    attr_reader :transactions, :spans, :errors, :metricsets

    # rubocop:disable Metrics/MethodLength
    def submit(obj)
      case obj
      when ElasticAPM::Transaction
        transactions << obj
      when ElasticAPM::Span
        spans << obj
      when ElasticAPM::Error
        errors << obj
      when ElasticAPM::Metricset
        metricsets << obj
      end

      true
    end

    def start; end

    def stop; end
  end
  # rubocop:enable Metrics/MethodLength

  config.before :each, intercept: true do
    @intercepted = Intercept.new

    allow(ElasticAPM::Transport::Base).to receive(:new) do |*_args|
      @intercepted
    end
  end

  config.after :each, intercept: true do
    @intercepted = nil
  end
end
