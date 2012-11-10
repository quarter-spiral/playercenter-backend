require 'bundler'
Bundler.setup

require 'playercenter-backend'

if !ENV['RACK_ENV'] || ENV['RACK_ENV'] == 'development'
  ENV['QS_OAUTH_CLIENT_ID'] ||= '953apz80uziz6618hkheki4eub4w6cy'
  ENV['QS_OAUTH_CLIENT_SECRET'] ||= 'm2ona42hvh7xthauditt63ri21qe1up'
end

run Playercenter::Backend::API
