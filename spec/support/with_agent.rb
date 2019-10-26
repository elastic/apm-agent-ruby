# frozen_string_literal: true

module WithAgent
  def with_agent(klass: ElasticAPM, args: [], **config)
    unless @mock_intake || @intercepted
      raise 'Using with_agent but neither MockIntake nor Intercepted'
    end

    klass.start(*args, **config)
    yield
  ensure
    ElasticAPM.stop
  end
end
