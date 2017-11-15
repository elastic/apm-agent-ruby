# frozen_string_literal: true

require 'bundler/gem_tasks'

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)

require 'yard'
YARD::Rake::YardocTask.new
task docs: :yard

task default: :spec
