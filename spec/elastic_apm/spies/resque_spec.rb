# frozen_string_literal: true

require 'spec_helper'
require 'fakeredis'

require 'resque'

require 'elastic_apm/spies/resque'

module ElasticAPM
  class TestJob
    extend ElasticAPM::Spies::ResqueSpy::Hooks

    @queue = :default

    def self.perform
      ElasticAPM.span('Things') do
        'ok'
      end
    end
  end

  RSpec.describe 'Resque', :with_fake_server do
    it 'instruments jobs' do
      # ENV['VERBOSE'] = '1'
      puts "Thread:#{Thread.current.object_id}"

      worker = Resque::Worker.new 'default'
      worker.prepare
      worker.log 'Starting'

      worker.startup
      Resque.enqueue(TestJob)

      worker.work_one_job

      expect(ElasticAPM.agent).to_not be_nil

      ElasticAPM.stop
      wait_for_requests_to_finish 1

      expect(FakeServer.requests.length).to be 1
    end
  end
end
