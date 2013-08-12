require 'bundler'
Bundler.setup

require 'playercenter-backend'

if !ENV['RACK_ENV'] || ENV['RACK_ENV'] == 'development'
  ENV['QS_OAUTH_CLIENT_ID'] ||= '953apz80uziz6618hkheki4eub4w6cy'
  ENV['QS_OAUTH_CLIENT_SECRET'] ||= 'm2ona42hvh7xthauditt63ri21qe1up'
end

class RackCors
  def initialize(app)
    @app = app
  end

  def call(env)
    response = options_request?(env) ? options_response : @app.call(env)

    response_with_cors_headers(env, *response)
  end

  protected
  def options_request?(env)
    env['REQUEST_METHOD'] == 'OPTIONS'
  end

  def options_response
    [204, {
      'Access-Control-Allow-Headers' => 'origin, x-requested-with, content-type, accept, authorization',
      'Access-Control-Allow-Methods' => 'GET, PUT, POST, DELETE, OPTIONS, PATCH, HEAD',
      'Access-Control-Max-Age' => '1728000'
    }, ['']]
  end

  def response_with_cors_headers(env, status, headers, body)
    headers['Access-Control-Allow-Origin'] = env['HTTP_ORIGIN'] || '*'
    [status, headers, body]
  end
end

use RackCors

require 'ping-middleware'
use Ping::Middleware

require 'raven'
require 'qs/request/tracker/raven_processor'
Raven.configure do |config|
  config.tags = {'app' => 'auth-backend'}
  config.processors = [Raven::Processor::SanitizeData, Qs::Request::Tracker::RavenProcessor]
end
use Raven::Rack
use Qs::Request::Tracker::Middleware

require 'rack/crossdomain/xml'
use Rack::Crossdomain::Xml::Middleware

require 'rack/fake_method'
use Rack::FakeMethod::Middleware

run Playercenter::Backend::API
