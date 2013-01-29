require 'grape'
require 'grape_newrelic'

module Playercenter::Backend
  class API < ::Grape::API
    use GrapeNewrelic::Instrumenter

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

    rescue_from Error::InvalidPlayerMetaDataError do |e|
        Rack::Response.new({
            'status' => 415,
            'message' => e.message
        }.to_json, 415)
    end

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

      def authentication_exception?
        env['PATH_INFO'] =~ /\/avatars\/[^\/]+$/ ||
env['PATH_INFO'] =~ /^\/public\//
      end

      def venue_identities_for(uuid)
        try_twice_and_avoid_token_expiration do
          begin
            connection.auth.venue_identities_of(token, uuid)
          rescue Service::Client::ServiceError => e
            error!(e.error, 404)
          end
        end
      end

      def strip_private_parts_from_venue_identities(venue_identities)
        Hash[venue_identities.map do |venue, venue_identity|
          public_identity = {
            'name' => venue_identity['name']
          }
          [venue, public_identity]
        end]
      end

      def get_games_for(uuid, venue = nil)
        games = try_twice_and_avoid_token_expiration do
          uuids = nil
          if venue
            venue = "venue#{Utils.camelize_string(venue)}"
            uuids = connection.graph.query(token, [uuid], "MATCH node0-[p:plays]->game WHERE p.#{venue}! = true RETURN DISTINCT game.uuid").map &:first
          else
            uuids = connection.graph.list_related_entities(uuid, token, 'plays')
          end

          connection.devcenter.list_games(uuids)
        end
        {games: games}
      end
    end

    before do
      header('Access-Control-Allow-Origin', request.env['HTTP_ORIGIN'] || '*')

      unless authentication_exception?
        error!('Unauthenticated', 403) unless request.env['HTTP_AUTHORIZATION']
        @request_token = request.env['HTTP_AUTHORIZATION'].gsub(/^Bearer\s+/, '')
        error!('Unauthenticated', 403) unless connection.auth.token_valid?(@request_token)
      end
    end

    options '*path' do
      header('Access-Control-Allow-Headers', 'origin, x-requested-with, content-type, accept, authorization')
      header('Access-Control-Allow-Methods', 'GET, PUT, OPTIONS, POST, DELETE')
      header('Access-Control-Max-Age', '1728000')
      ""
    end

    get "public/:uuid" do
      uuid = params[:uuid]
      venue_identities = venue_identities_for(uuid)
      venue_identities = strip_private_parts_from_venue_identities(venue_identities)
      {uuid: uuid, venues: venue_identities}
    end

    get "public/:uuid/friends" do
      requester_uuid = params[:uuid]

      try_twice_and_avoid_token_expiration do
        uuids = connection.graph.list_related_entities(requester_uuid, token, 'friends')

        uuids.unshift requester_uuid
        uuids.uniq!

        identities = connection.auth.venue_identities_of(token, *uuids)

        # Make up for the different response format of the auth-backend
        # depending on if you request venue identities for one or many
        # UUIDs
        identities = {uuids.first => identities} if uuids.size == 1

        Hash[identities.map {|uuid, identities| [uuid, strip_private_parts_from_venue_identities(identities)]}]
      end
    end

    get "/public/:uuid/games" do
      get_games_for(params[:uuid], params[:venue])
    end

    get ":uuid" do
      uuid = params[:uuid]
      venue_identities = venue_identities_for(uuid)
      {uuid: uuid, venues: venue_identities}
    end

    get ":uuid/games" do
      get_games_for(params[:uuid], params[:venue])
    end

    get ":uuid/games/friends" do
      uuid = params[:uuid]
      venue = params[:venue]

      games = try_twice_and_avoid_token_expiration do
        uuids = nil
        if venue
          venue = "venue#{Utils.camelize_string(venue)}"
          uuids = connection.graph.query(token, [uuid], "MATCH node0-[:friends]->()-[p:plays]->game WHERE p.#{venue}! = true RETURN DISTINCT game.uuid")
        else
          uuids = connection.graph.query(token, [uuid], 'MATCH node0-[:friends]->()-[:plays]->game RETURN DISTINCT game.uuid')
        end
        connection.devcenter.list_games(uuids.map &:first)
      end
      {games: games}
    end


    get ":player_uuid/games/:game_uuid/meta-data" do
      player = params[:player_uuid]
      game = params[:game_uuid]
      data = try_twice_and_avoid_token_expiration do
        connection.graph.relationship_metadata(player, game, token, 'plays')
      end
      {meta: MetaData.from_graph(data)}
    end


    [":player_uuid/games/:game_uuid/meta-data", ":player_uuid/games/:game_uuid/meta-data/:property"].each do |url|
      put url do
        player = params[:player_uuid]
        game = params[:game_uuid]
        data = (params[:meta] || {}).to_hash
        property = params[:property]

        old_data = MetaData.from_graph(connection.graph.relationship_metadata(player, game, token, 'plays'))

        data = try_twice_and_avoid_token_expiration do
          if property
            if data.has_key?(property)
              new_value = data.delete(property)
              new_data = {property => new_value}
              data = old_data.merge(new_data)
            else
              data = old_data
            end
          end

          response = connection.graph.add_relationship(player, game, token, 'plays', meta: MetaData.to_graph(data))
          response.raw.status == 200 ? response.data.first['meta'] : MetaData.to_graph(old_data)
        end
        {meta: MetaData.from_graph(data)}
      end
    end

    post ":player_uuid/games/:game_uuid/:venue" do
      player = params[:player_uuid]
      game = params[:game_uuid]
      venue = params[:venue]
      venue = Utils.camelize_string(venue)

      try_twice_and_avoid_token_expiration do
        connection.graph.add_role(player, token, 'player')
        response = connection.graph.add_relationship(player, game, token, 'plays', meta: {"venue#{venue}" => true})
        status response.raw.status
      end

      ''
    end

    get ":uuid/friends" do
      requester_uuid = params[:uuid]
      game = params[:game]
      meta = params[:meta]
      meta = JSON.parse(meta) if meta && meta.kind_of?(String)
      meta_results = nil

      try_twice_and_avoid_token_expiration do
        uuids = nil
        if game
          query = "MATCH node0-[:friends]->friend-[p:plays]->game WHERE game = node1 RETURN DISTINCT friend.uuid"
          query = "#{query}, #{meta.map {|m| "p.#{MetaData::PREFIX}#{m}!"}.join(', ')}" if meta
          uuids = []
          meta_results = {}
          connection.graph.query(token, [requester_uuid, game], query).each do |result|
            uuid = result.shift
            uuids << uuid
            meta_results[uuid] = result
          end
        else
          uuids = connection.graph.list_related_entities(requester_uuid, token, 'friends')
        end
        uuids.unshift requester_uuid
        uuids.uniq!

        identities = connection.auth.venue_identities_of(token, *uuids)

        # Make up for the different response format of the auth-backend
        # depending on if you request venue identities for one or many
        # UUIDs
        identities = {uuids.first => identities} if uuids.size == 1

        if meta && meta_results
          requester_meta_query  = "MATCH node0-[p:plays]->game WHERE game = node1 RETURN DISTINCT node0.uuid"
          requester_meta_query  = "#{requester_meta_query }, #{meta.map {|m| "p.#{MetaData::PREFIX}#{m}!"}.join(', ')}"
          result = connection.graph.query(token, [requester_uuid, game], requester_meta_query ).first
          meta_results[requester_uuid] = result[1..-1]

          identities = Hash[identities.map {|uuid, identity| [uuid, identity.merge('meta' => Hash[meta.zip(meta_results[uuid])])]}]
        end

        identities
      end
    end

    put ":uuid/friends/:venue_id" do
      token_uuid = connection.auth.token_owner(@request_token)['uuid']
      error!("You can only add friends for yourself!", 403) unless token_uuid == params[:uuid]

      body = request.body
      body = body.read if body.respond_to?(:read)
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

    get ":uuid/avatars/:venue_id" do
      venue_identities = try_twice_and_avoid_token_expiration do
        connection.auth.venue_identities_of(token, params[:uuid])
      end
      # identity = venue_identities[params[:venue_id]]
      identity = venue_identities['facebook'] # <-- Dirty hack till we have real friends on all venues

      redirect "https://graph.facebook.com/#{identity['id']}/picture"
    end
  end
end

