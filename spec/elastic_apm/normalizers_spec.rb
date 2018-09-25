# frozen_string_literal: true

enable = false
begin
  require 'active_support/notifications'
  enable = true
rescue LoadError
  puts '[INFO] Skipping Normalizers spec'
end

if enable
  require 'elastic_apm/subscriber'

  module ElasticAPM
    RSpec.describe Normalizers do
      describe 'registration:' do
        it 'allows a normalizer to register itself' do
          class TestNormalizer < Normalizers::Normalizer
            register 'something'
          end

          built = Normalizers.build nil
          expect(built.for('something')).to be_a TestNormalizer
          expect(built.keys).to include 'something'
        end
      end
    end
  end
end
