# frozen_string_literal: true

module WithAgent
  def with_agent(klass: ElasticAPM, **config)
    unless @mock_intake || @intercepted
      raise 'Using with_agent but neither MockIntake nor Intercepted'
    end

    ElasticAPM.start(config)
    yield
  ensure
    ElasticAPM.stop
  end
end
