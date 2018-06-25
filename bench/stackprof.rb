# frozen_string_literal: true

Dir.chdir('./bench')

ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

require 'stackprof'
require 'rack/test'
require 'elastic-apm'

ElasticAPM.start environment: 'bench', enabled_environments: ['bench']

env = Rack::MockRequest.env_for('/')

puts 'Running '
profile = StackProf.run(mode: :cpu) do
  10_000.times do
    ElasticAPM.transaction 'Name', 'custom',
      context: ElasticAPM.build_context(env) do
      ElasticAPM.span 'Number one' do
        'ok'
      end
      ElasticAPM.span 'Number two' do
        'ok'
      end
      ElasticAPM.span 'Number three' do
        'ok'
      end
    end
  end
end
puts ''

ElasticAPM.stop

StackProf::Report.new(profile).print_text
