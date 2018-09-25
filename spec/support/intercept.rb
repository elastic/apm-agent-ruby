# frozen_string_literal: true

RSpec.configure do |config|
  class Intercept
    def initialize
      @transactions = []
      @spans = []
      @errors = []
    end

    attr_reader :transactions, :spans, :errors
  end

  config.before :each, intercept: true do
    @intercepted = Intercept.new

    allow_any_instance_of(ElasticAPM::Agent).to receive(:enqueue) do |_, obj|
      case obj
      when ElasticAPM::Transaction
        @intercepted.transactions << obj
      when ElasticAPM::Span
        @intercepted.spans << obj
      when ElasticAPM::Error
        @intercepted.errors << obj
      end

      true
    end
  end
end
