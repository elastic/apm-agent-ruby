# frozen_string_literal: true

module WithAgent
  # rubocop:disable Metrics/MethodLength
  def with_agent(klass: ElasticAPM, args: [], **config)
    unless @mock_intake || @intercepted
      raise 'Using with_agent but neither MockIntake nor Intercepted'
    end

    @central_config_stub ||=
      WebMock.stub_request(
        :get, %r{^http://localhost:8200/config/v1/agents/?$}
      ).to_return(body: '{}')

    klass.start(*args, **config)
    yield
  ensure
    ElasticAPM.stop

    @central_config_stub = nil
  end
  # rubocop:enable Metrics/MethodLength
end
