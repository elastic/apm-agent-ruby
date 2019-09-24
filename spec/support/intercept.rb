# frozen_string_literal: true

RSpec.configure do
  class Intercept
    def initialize
      @transactions = []
      @spans = []
      @errors = []
      @metricsets = []
    end

    attr_reader :transactions, :spans, :errors, :metricsets

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
      else
        raise "Unknown resource submitted to intercepted Transport! #{obj}"
      end

      true
    end

    def start; end
    def stop; end
  end
end

RSpec.shared_context 'intercept', shared_contex: :metadata do
  let(:config) { ElasticAPM::Config.new }
  let(:agent) { ElasticAPM.agent }
  before(:each) { start_intercepted_agent(config) }

  after(:each) do
    ElasticAPM.stop
    @intercepted = nil
  end

  def start_intercepted_agent(config = ElasticAPM::Config.new)
    @intercepted = Intercept.new
    ElasticAPM.start(config).tap do |agent|
      allow(agent).to receive(:transport).and_return(@intercepted)
    end
  end
end
