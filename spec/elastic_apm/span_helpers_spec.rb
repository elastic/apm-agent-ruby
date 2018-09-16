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

    context 'on class methods' do
      it 'wraps in a span' do
        ElasticAPM.start disable_send: true

        transaction = ElasticAPM.transaction do
          Thing.do_all_things
        end.done

        expect(transaction.spans.length).to be 1
        expect(transaction.spans.last.name).to eq 'do_all_things'

        ElasticAPM.stop
      end
    end

    context 'on instance methods' do
      it 'wraps in a span' do
        thing = Thing.new

        ElasticAPM.start disable_send: true

        transaction = ElasticAPM.transaction do
          thing.do_the_thing
        end.done

        expect(transaction.spans.length).to be 1
        expect(transaction.spans.last.name).to eq 'do_the_thing'

        ElasticAPM.stop
      end
    end
  end
end
