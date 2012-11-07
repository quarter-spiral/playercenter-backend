source 'https://rubygems.org'

# Specify your gem's dependencies in playercenter-backend.gemspec
gemspec

gem 'auth-client', path: '../auth-client'

group :development, :test do
  gem 'rack-client'
  gem 'uuid'
  gem 'rake'

  gem 'graph-backend', "~> 0.0.10"
  gem 'auth-backend', "~> 0.0.9"
  gem 'nokogiri'
  gem 'sqlite3'
  gem 'sinatra_warden', git: 'https://github.com/quarter-spiral/sinatra_warden.git'
  gem 'songkick-oauth2-provider', git: 'https://github.com/quarter-spiral/oauth2-provider.git'
end
