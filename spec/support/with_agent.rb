# frozen_string_literal: true

module WithAgent
  def with_agent(klass: ElasticAPM, args: [], config: nil, **config_hash)
    unless @mock_intake || @intercepted
      raise 'Using with_agent but neither MockIntake nor Intercepted'
    end

    @central_config_stub ||=
      WebMock.stub_request(
        :get, %r{^http://localhost:8200/config/v1/agents/?$}
      ).to_return(body: '{}')

    if config_hash
      klass.start(*args, **config_hash)
    else
      klass.start(*args, config)
    end
    yield
  ensure
    ElasticAPM.stop

    @central_config_stub = nil
  end
end
