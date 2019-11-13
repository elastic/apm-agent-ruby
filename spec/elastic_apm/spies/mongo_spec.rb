# frozen_string_literal: true

require 'mongo'

module ElasticAPM
  RSpec.describe 'Spy: MongoDB' do
    context 'db admin commands' do
      let(:event) do
        double('event',
          command: { 'listCollections' => 1 },
          command_name: 'listCollections',
          database_name: 'elastic-apm-test',
          operation_id: 123)
      end
      let(:subscriber) { Spies::MongoSpy::Subscriber.new }

      it 'captures command properties', :intercept do
        span = with_agent do
          ElasticAPM.with_transaction do
            subscriber.started(event)
            subscriber.succeeded(event)
          end
        end

        expect(span.name).to eq 'elastic-apm-test.listCollections'
        expect(span.type).to eq 'db'
        expect(span.subtype).to eq 'mongodb'
        expect(span.action).to eq 'query'
        expect(span.duration).to_not be_nil

        db = span.context.db
        expect(db.instance).to eq 'elastic-apm-test'
        expect(db.type).to eq 'mongodb'
        expect(db.statement).to eq('{"listCollections"=>1}')
        expect(db.user).to be nil
      end
    end

    context 'collection commands', :intercept do
      let(:event) do
        double('event',
          command: { 'find' => 'testing',
                     'filter' => { 'a' => 'bc' } },
          command_name: 'find',
          database_name: 'elastic-apm-test',
          operation_id: 456)
      end
      let(:subscriber) { Spies::MongoSpy::Subscriber.new }

      it 'captures command properties' do
        span = with_agent do
          ElasticAPM.with_transaction do
            subscriber.started(event)
            subscriber.succeeded(event)
          end
        end

        expect(span.name).to eq 'elastic-apm-test.testing.find'
        expect(span.type).to eq 'db'
        expect(span.subtype).to eq 'mongodb'
        expect(span.action).to eq 'query'
        expect(span.duration).to_not be_nil

        db = span.context.db
        expect(db.instance).to eq 'elastic-apm-test'
        expect(db.type).to eq 'mongodb'
        expect(db.statement).to eq('{"find"=>"testing", "filter"=>{"a"=>"bc"}}')
        expect(db.user).to be nil
      end
    end
  end
end
