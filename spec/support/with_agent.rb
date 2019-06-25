# frozen_string_literal: true

module WithAgent
  def with_agent(config = {})
    ElasticAPM.start(config)
    yield
  ensure
    ElasticAPM.stop
  end
end
