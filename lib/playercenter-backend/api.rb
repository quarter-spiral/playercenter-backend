require 'grape'

module Playercenter::Backend
  class API < ::Grape::API
    class TokenStore
      def self.token(connection)
        @token ||= connection.auth.create_app_token(ENV['QS_OAUTH_CLIENT_ID'], ENV['QS_OAUTH_CLIENT_SECRET'])
      end

      def self.reset!
        @token = nil
      end
    end

    version 'v1', :using => :path, :vendor => 'quarter-spiral'

    content_type :json, "application/json;charset=utf-8"
    format :json
    default_format :json

    error_format :json

    helpers do
      def connection
        @connection ||= Connection.create
      end

      def not_found!
        error!('Not found', 404)
      end

      def token
        TokenStore.token(connection)
      end

      def try_twice_and_avoid_token_expiration
        yield
      rescue Service::Client::ServiceError => e
        raise e unless e.error == 'Unauthenticated'
        TokenStore.reset!
        yield
      end
    end

    before do
      unless request.env['REQUEST_METHOD'] == 'OPTIONS'
        error!('Unauthenticated', 403) unless request.env['HTTP_AUTHORIZATION']
        @request_token = request.env['HTTP_AUTHORIZATION'].gsub(/^Bearer\s+/, '')
        error!('Unauthenticated', 403) unless connection.auth.token_valid?(@request_token)
      end
    end

    get ":uuid" do
      uuid = params[:uuid]
      venue_identities = try_twice_and_avoid_token_expiration do
        begin
          connection.auth.venue_identities_of(token, uuid)
        rescue Service::Client::ServiceError => e
          error!(e.error, 404)
        end
      end
      {uuid: uuid, venues: venue_identities}
    end

    get ":uuid/friends" do
      uuid = params[:uuid]

      try_twice_and_avoid_token_expiration do
        uuids = connection.graph.list_related_entities(uuid, token, 'friends')

        identities = connection.auth.venue_identities_of(token, *uuids)

        # Make up for the different response format of the auth-backend
        # depending on if you request venue identities for one or many
        # UUIDs
        identities = {uuids.first => identities} if uuids.size == 1

        identities
      end
    end

    put ":uuid/friends/:venue_id" do
      token_uuid = connection.auth.token_owner(@request_token)['uuid']
      error!("You can only add friends for yourself!", 403) unless token_uuid == params[:uuid]

      body = request.body
      body =body.read if body.respond_to?(:read)
      friends_data = params[:friends]

      venue_id = params[:venue_id]
      friend_uuids = try_twice_and_avoid_token_expiration do
        connection.auth.uuids_of(token, venue_id => friends_data)[venue_id]
      end

      venue = Venue.const_get(Utils.camelize_string(venue_id)).new
      friend_uuids.values.each do |friend_uuid|
        try_twice_and_avoid_token_expiration do
          venue.friend(token_uuid, friend_uuid, token, connection)
        end
      end

      ''
    end
  end
end

