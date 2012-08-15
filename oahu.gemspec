# -*- encoding: utf-8 -*-
require File.expand_path('../lib/oahu/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Stephane Bellity", "Oahu"]
  gem.email         = ["sbellity@gmail.com"]
  gem.description   = %q{Oahu API Ruby Client}
  gem.summary       = %q{Oahu API Ruby Client}
  gem.homepage      = "http://oahu.fr"

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "oahu"
  gem.require_paths = ["lib"]
  gem.version       = Oahu::VERSION

  # Dependencies
  gem.add_dependency 'faraday',               '~> 0.7'
  gem.add_dependency 'faraday_middleware',    '~> 0.7'
  gem.add_dependency 'multi_json',            '~> 1.0'
  gem.add_dependency 'multi_xml' #,            '~> 1.0'
  gem.add_dependency 'mime-types'
  gem.add_dependency 'toystore',  ['>= 0.10', '< 1']

  # Development Dependencies
  gem.add_development_dependency 'activesupport',       ['>= 2.3.9', '< 4']
  gem.add_development_dependency 'redis-activesupport'

end
