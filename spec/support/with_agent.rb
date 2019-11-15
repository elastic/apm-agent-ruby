# frozen_string_literal: true

module WithAgent
  # rubocop:disable Metrics/MethodLength
  def with_agent(klass: ElasticAPM, args: [], **config)
    unless @mock_intake || @intercepted
      raise 'Using with_agent but neither MockIntake nor Intercepted'
    end

    klass.start(*args, DISABLED_SEND_AGENT_OPTIONS.merge(**config))
    yield
  ensure
    ElasticAPM.stop
  end
  # rubocop:enable Metrics/MethodLength
end
