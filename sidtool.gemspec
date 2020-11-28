lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "sidtool/version"

Gem::Specification.new do |spec|
  spec.name          = 'sidtool'
  spec.version       = Sidtool::VERSION
  spec.authors       = ['Ole Friis Østergaard']
  spec.email         = ['olefriis@gmail.com']

  spec.summary       = 'Convert SID tunes to other formats'
  spec.homepage      = 'https://github.com/olefriis/sidtool'
  spec.license       = 'MIT'

  spec.required_ruby_version = '>= 2.3'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.executables   = 'sidtool'
  spec.require_paths = ['lib']

  spec.add_dependency 'mos6510', '~> 0.1.1'
  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'pry', '~> 0.12.2'
end
