# Backport Enumerable#dig to Ruby < 2.3
#
# Implementation from
#   https://github.com/Invoca/ruby_dig/blob/master/lib/ruby_dig.rb

# @api private
module RubyDig
  def dig(key, *rest)
    value = self[key]

    if value.nil? || rest.empty?
      value
    elsif value.respond_to?(:dig)
      value.dig(*rest)
    else
      raise TypeError, "#{value.class} does not respond to `#dig'"
    end
  end
end

if RUBY_VERSION < '2.3'
  # @api private
  class Array
    include RubyDig
  end

  # @api private
  class Hash
    include RubyDig
  end
end
