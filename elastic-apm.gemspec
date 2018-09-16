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
  spec.metadata     = { 'source_code_uri' => 'https://github.com/elastic/apm-agent-ruby' }
  spec.license       = 'Apache-2.0'
  spec.required_ruby_version = ">= 2.2.0"

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end

  spec.add_dependency('concurrent-ruby', '~> 1.0.0')
  spec.add_dependency('http', '~> 3.0')

  spec.require_paths = ['lib']
end
