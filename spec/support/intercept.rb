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
  end

  config.before :each, intercept: true do
    @intercepted = Intercept.new

    allow_any_instance_of(ElasticAPM::Transport::Base)
      .to receive(:submit) do |_, obj|
      case obj
      when ElasticAPM::Transaction
        @intercepted.transactions << obj
      when ElasticAPM::Span
        @intercepted.spans << obj
      when ElasticAPM::Error
        @intercepted.errors << obj
      when ElasticAPM::Metricset
        @intercepted.metricsets << obj
      end

      true
    end
  end

  config.after :each, intercept: true do
    @intercepted = nil
  end
end
