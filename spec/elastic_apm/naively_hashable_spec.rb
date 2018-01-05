require 'spec_helper'

module ElasticAPM
  RSpec.describe NaivelyHashable do
    class Outer
      include NaivelyHashable

      def initialize(inner)
        @inner = inner
      end
    end

    class Inner
      include NaivelyHashable

      def initialize(name)
        @name = name
      end
    end

    it 'converts object into hash from ivars' do
      expect(Outer.new(Inner.new('Ron Burgundy')).to_h).to eq(
        inner: { name: 'Ron Burgundy' }
      )
    end
  end
end
