# frozen_string_literal: true

RSpec::Matchers.define :delegate do |method, opts|
  to = opts[:to]
  args = opts[:args]

  match do |delegator|
    unless to.respond_to?(method)
      raise NoMethodError, "no method `#{method}` on #{to.inspect}"
    end

    if args
      expect(to).to receive(method).with(*args) { true }
    else
      expect(to).to receive(method).with(no_args) { true }
    end

    delegator.send method, *args
  end

  description do
    "delegate :#{method} to #{to}"
  end
end
