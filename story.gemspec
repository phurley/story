# frozen_string_literal: true

require_relative 'lib/story'

# story.gemspec
Gem::Specification.new do |spec|
  spec.name          = 'story'
  spec.version       = Story::VERSION
  spec.authors       = ['Patrick Hurley']
  spec.email         = ['phurley@gmail.com']

  spec.summary       = 'A storytelling AI command-line tool'
  spec.description   = 'Runs AI-based story scripts from the command line.'
  spec.homepage      = 'https://github.com/phurley/story'
  spec.license       = 'MIT'

  spec.files         = Dir.glob('{bin,lib}/**/*') + %w[README.md LICENSE.txt]
  spec.bindir        = 'bin'
  spec.executables   = ['story']
  spec.require_paths = ['lib']

  spec.add_dependency 'faker', '~> 3.0'
  spec.add_dependency 'mime-types', '~> 3.7'
  spec.add_dependency 'ollama-ai', '~> 1.3'

  spec.metadata['source_code_uri'] = spec.homepage
  spec.required_ruby_version = '>= 2.7'
end

