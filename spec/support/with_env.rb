# frozen_string_literal: true

module WithEnv
  def with_env(env)
    current_values = env.keys.each_with_object({}) do |(key, value), current|
      current[key] = ENV.key?(key) ? ENV[value] : :__missing
    end

    env.each_key { |key| ENV[key] = env[key] }

    yield
  ensure
    current_values.each do |key, value|
      case value
      when :__missing
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
  end
end

RSpec.configure do |config|
  config.include WithEnv
end
