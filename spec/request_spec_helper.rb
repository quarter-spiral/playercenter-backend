require_relative './spec_helper'

include Playercenter::Backend

ENV['QS_AUTH_BACKEND_URL'] = 'http://auth-backend.dev'

API_APP  = API.new
AUTH_APP = Auth::Backend::App.new(test: true)

module Auth
  class Client
    alias raw_initialize initialize
    def initialize(url, options = {})
      raw_initialize(url, options.merge(adapter: [:rack, AUTH_APP]))
    end
  end
end

class AuthenticationInjector
  def self.token=(token)
    @token = token
  end

  def self.token
    @token
  end

  def self.reset!
    @token = nil
  end

  def initialize(app)
    @app = app
  end

  def call(env)
    if token = self.class.token
      env['HTTP_AUTHORIZATION'] = "Bearer #{token}"
    end

    @app.call(env)
  end
end

class ContentTypeInjector
  def initialize(app)
    @app = app
  end

  def call(env)
    env['CONTENT_TYPE'] = 'application/json' if env['CONTENT_TYPE'] == 'application/x-www-form-urlencoded'
    body = Rack::Request.new(env).body
    env['CONTENT_LENGTH'] = body.length if body
    @app.call(env)
  end
end


def client
  return @client if @client

  @client = Rack::Client.new {
    use AuthenticationInjector
    use ContentTypeInjector
    run API_APP
  }

  def @client.get(url, headers = {}, body = '', &block)
    request('GET', url, headers, body, {}, &block)
  end
  def @client.delete(url, headers = {}, body = '', &block)
    request('DELETE', url, headers, body, {}, &block)
  end

  @client
end

def connection
  @connection ||= Connection.create
end

require 'auth-backend/test_helpers'
AUTH_HELPERS = Auth::Backend::TestHelpers.new(AUTH_APP)
OAUTH_APP = AUTH_HELPERS.create_app!
ENV['QS_OAUTH_CLIENT_ID'] = OAUTH_APP[:id]
ENV['QS_OAUTH_CLIENT_SECRET'] = OAUTH_APP[:secret]

def token
  @token ||= AUTH_HELPERS.get_token
end

def user
  @user ||= AUTH_HELPERS.user_data
end

def app_token
  @app_token ||= connection.auth.create_app_token(OAUTH_APP[:id], OAUTH_APP[:secret])
end
