
# frozen_string_literal: true

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'elastic_apm/version'

Gem::Specification.new do |spec|
  spec.name          = 'elastic-apm'
  spec.version       = ElasticAPM::VERSION
  spec.authors       = ['Mikkel Malmberg']
  spec.email         = ['mikkel@elastic.co']

  spec.summary       = 'The official Elastic APM agent for Ruby'
  spec.homepage      = 'https://github.com/elastic/apm-agent-ruby'
  spec.license       = 'Apache-2.0'

  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
      'public gem pushes.'
  end

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']
end
