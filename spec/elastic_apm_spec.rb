# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ElasticAPM do
  describe 'life cycle' do
    it 'starts and stops the agent' do
      ElasticAPM.start ElasticAPM::Config.new
      expect(ElasticAPM::Agent).to be_running

      ElasticAPM.stop
      expect(ElasticAPM::Agent).to_not be_running
    end

    it 'has a current_transaction' do
      ElasticAPM.start
      ElasticAPM.transaction 'T'

      expect(ElasticAPM.current_transaction).to be_a ElasticAPM::Transaction

      ElasticAPM.stop

      expect(ElasticAPM.current_transaction).to be nil
    end
  end
end
