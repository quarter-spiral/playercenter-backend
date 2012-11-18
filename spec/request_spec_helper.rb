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

def client
  @client ||= Rack::Client.new {
    run API_APP
  }
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
