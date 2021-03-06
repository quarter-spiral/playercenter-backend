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

  gem.add_dependency 'auth-client', '>= 0.0.17'
  gem.add_dependency 'graph-client', '>= 0.0.13'
  gem.add_dependency 'devcenter-client', '>= 0.0.5'

  gem.add_dependency 'grape', '>=0.2.2'
  gem.add_dependency 'json', '1.7.7'
  gem.add_dependency 'ping-middleware', '~> 0.0.2'
  gem.add_dependency 'grape_newrelic', '~> 0.0.3'
  gem.add_dependency 'cache-client', '~> 0.0.4'
  gem.add_dependency 'cache-backend-iron-cache', '~> 0.0.4'
  gem.add_dependency 'rack-crossdomain-xml', '~> 0.0.1'
  gem.add_dependency 'rack-fake-method', '~> 0.0.1'
  gem.add_dependency 'futuroscope', '>= 0.1.3'
  gem.add_dependency 'qs-request-tracker', '>= 0.0.2'
  gem.add_dependency 'sentry-raven'
end
