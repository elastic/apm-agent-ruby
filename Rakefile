# frozen_string_literal: true

require 'bundler/gem_tasks'

desc """Post release action:
Update `3.x` branch to be at released commit and push it to GitHub.
"""
task :syncup => :environment do
  `git checkout 3.x &&
  git rebase master &&
  git push origin 3.x &&
  git checkout master`
end

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)

require 'yard'
YARD::Rake::YardocTask.new
task docs: :yard

task default: :spec
