# frozen_string_literal: true

require 'spec_helper'
require 'fakeredis'

require 'resque'

require 'elastic_apm/spies/resque'

# begin
#   require 'active_job'
# rescue LoadError
# end

module ElasticAPM
  class TestJob
    extend ElasticAPM::Spies::ResqueSpy::Hooks

    @queue = :default

    def self.perform
      puts '#' * 90
      puts 'Agent:'
      pp ElasticAPM.agent
      puts '#' * 90
      ElasticAPM.span('Things') do
        puts '#' * 90
        puts 'you rang?'
        puts '#' * 90
      end
    end
  end

  RSpec.describe 'Resque', :with_fake_server do
    it 'instruments jobs' do
      ENV['VERBOSE'] = '1'
      worker = Resque::Worker.new 'default'
      worker.prepare
      worker.log 'Starting'

      thread = Thread.new { worker.work 1 }
      Resque.enqueue(TestJob)

      thread.join 2

      expect(ElasticAPM.agent).to_not be_nil

      ElasticAPM.stop

      wait_for_requests_to_finish 1

      expect(FakeServer.requests.length).to be 1
    end
  end
end
