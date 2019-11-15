# frozen_string_literal: true

module WithAgent
  DEFAULT_OPTIONS = { central_config: false, http_compression: false }

  # rubocop:disable Metrics/MethodLength
  def with_agent(klass: ElasticAPM, args: [], **config)
    unless @mock_intake || @intercepted
      raise 'Using with_agent but neither MockIntake nor Intercepted'
    end

    klass.start(*args, **config.merge(DEFAULT_OPTIONS))
    yield
  ensure
    ElasticAPM.stop
  end
  # rubocop:enable Metrics/MethodLength
end
