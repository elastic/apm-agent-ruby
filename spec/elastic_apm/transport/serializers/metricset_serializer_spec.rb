# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  module Transport
    module Serializers
      RSpec.describe MetricsetSerializer do
        subject { described_class.new Config.new }

        describe '#build' do
          let(:set) { Metricset.new(thing: 1.0, other: 321, tags: { a: 1 }) }
          let(:result) { subject.build(set) }

          it 'matches' do
            expect(result).to match(
              metricset: {
                timestamp: Integer,
                tags: { a: 1 },
                samples: {
                  thing: { value: 1.0 },
                  other: { value: 321 }
                }
              }
            )
          end

          context 'with a transaction' do
            let(:set) do
              Metricset.new(
                'transaction.breakdown.count': 1,
                transaction: { name: 'txn', type: 'app' }
              )
            end

            it 'matches' do
              expect(result).to match(
                metricset: {
                  timestamp: Integer,
                  samples: {
                    'transaction.breakdown.count': { value: 1 }
                  },
                  transaction: {
                    name: 'txn',
                    type: 'app'
                  }
                }
              )
            end
          end

          context 'with a transaction and span' do
            let(:set) do
              Metricset.new(
                'transaction.breakdown.count': 1,
                transaction: { name: 'txn', type: 'app' },
                span: { type: 'db', subtype: 'mysql' }
              )
            end

            it 'matches' do
              expect(result).to match(
                metricset: {
                  timestamp: Integer,
                  samples: {
                    'transaction.breakdown.count': { value: 1 }
                  },
                  transaction: {
                    name: 'txn',
                    type: 'app'
                  },
                  span: {
                    type: 'db',
                    subtype: 'mysql'
                  }
                }
              )
            end
          end
        end
      end
    end
  end
end
