# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'playercenter-backend/version'

Gem::Specification.new do |gem|
  gem.name          = "playercenter-backend"
  gem.version       = Playercenter::Backend::VERSION
  gem.authors       = ["Thorben Schröder"]
  gem.email         = ["stillepost@gmail.com"]
  gem.description   = %q{A backend to gather and store data about players.}
  gem.summary       = %q{A backend to gather and store data about players.}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency 'auth-client', '>= 0.0.13'
  gem.add_dependency 'graph-client', '>= 0.0.11'
  gem.add_dependency 'devcenter-client', '>= 0.0.2'

  gem.add_dependency 'grape', '>=0.2.2'
  gem.add_dependency 'json', '1.7.4'
end
