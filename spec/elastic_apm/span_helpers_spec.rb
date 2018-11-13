# frozen_string_literal: true

require 'elastic_apm/span_helpers'

module ElasticAPM
  RSpec.describe SpanHelpers do
    class Thing
      include ElasticAPM::SpanHelpers

      def do_the_thing
        'ok'
      end
      span_method :do_the_thing

      def self.do_all_things
        'all ok'
      end
      span_class_method :do_all_things
    end

    context 'on class methods', :intercept do
      it 'wraps in a span' do
        ElasticAPM.start

        ElasticAPM.with_transaction do
          Thing.do_all_things
        end

        ElasticAPM.stop

        expect(@intercepted.spans.length).to be 1
        expect(@intercepted.spans.last.name).to eq 'do_all_things'
      end
    end

    context 'on instance methods', :intercept do
      it 'wraps in a span' do
        thing = Thing.new

        ElasticAPM.start

        ElasticAPM.with_transaction do
          thing.do_the_thing
        end

        ElasticAPM.stop

        expect(@intercepted.spans.length).to be 1
        expect(@intercepted.spans.last.name).to eq 'do_the_thing'
      end
    end
  end
end
