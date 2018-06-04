# frozen_string_literal: true

require 'elastic_apm/normalizers'

module ElasticAPM
  module Normalizers
    module ActionController
      RSpec.describe ProcessActionNormalizer do
        it 'registers for name' do
          normalizers = Normalizers.build(nil)
          subject = normalizers.for('process_action.action_controller')

          expect(subject).to be_a ProcessActionNormalizer
        end

        describe '#normalize' do
          it 'sets transaction name from payload' do
            subject = ProcessActionNormalizer.new nil
            transaction = Transaction.new nil, 'Rack'

            result = subject.normalize(
              transaction,
              'process_action.action_controller',
              controller: 'UsersController', action: 'index'
            )
            expected = ['UsersController#index', 'app.controller.action', nil]

            expect(result).to eq expected
          end
        end
      end
    end
  end
end
