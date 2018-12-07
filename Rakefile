# frozen_string_literal: true

require 'bundler/gem_tasks'

Rake::Task[:release].enhance do
  `git checkout 2.x &&
  git rebase master &&
  git push origin 2.x &&
  git checkout master`
end

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)

require 'yard'
YARD::Rake::YardocTask.new
task docs: :yard

task default: :spec
