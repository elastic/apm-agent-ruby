# frozen_string_literal: true

RSpec::Matchers.define :delegate do |method, opts|
  to = opts[:to]
  args = opts[:args]

  match do |delegator|
    unless to.respond_to?(method)
      raise NoMethodError, "no method `#{method}` on #{to.inspect}"
    end

    if args
      expect(to).to receive(method).at_least(:once).with(*args) { true }
    else
      expect(to).to receive(method).at_least(:once).with(no_args) { true }
    end

    if args&.last.is_a?(Hash)
      kw = args.pop
      delegator.send method, *args, **kw
    else
      delegator.send method, *args
    end
  end

  description do
    "delegate :#{method} to #{to}"
  end
end
