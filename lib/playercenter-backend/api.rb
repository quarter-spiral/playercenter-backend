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

    format :json
    default_format :json

    default_error_formatter :json

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
env['PATH_INFO'] =~ /^\/v1\/public\//
      end

      def own_data?(uuid)
        @token_owner['uuid'] == uuid
      end

      def system_level_privileges?
        @token_owner['type'] == 'app'
      end

      def is_authorized_to_access?(uuid)
        system_level_privileges? || own_data?(uuid)
      end

      def prevent_access!
        error!('Unauthenticated', 403)
      end

      def owner_only!(uuid = params[:uuid])
        prevent_access! unless is_authorized_to_access?(uuid)
      end

      def system_privileges_only!
        prevent_access! unless system_level_privileges?
      end

      def venue_identities_for(uuids)
        result = try_twice_and_avoid_token_expiration do
          begin
            if uuids.kind_of?(Array)
              connection.auth.venue_identities_of(token, *uuids)
            else
              connection.auth.venue_identities_of(token, uuids)
            end
          rescue Service::Client::ServiceError => e
            error!(e.error, 404)
          end
        end

        result = Hash[[[uuids, result]]] unless uuids.kind_of?(Array)
        result
      end

      def strip_private_parts_from_venue_identities(venue_identities)
        Hash[venue_identities.map do |venue, venue_identity|
          public_identity = {
            'name' => venue_identity['name']
          }
          [venue, public_identity]
        end]
      end

      def public_venue_identity_info_for(venue_identities_data)
        Hash[venue_identities_data.map do |uuid, venue_identities|
          venue_identities = strip_private_parts_from_venue_identities(venue_identities)
          [uuid, {uuid: uuid, venues: venue_identities}]
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

          if !uuids || uuids.empty?
            []
          else
            connection.devcenter.list_games(uuids)
          end
        end
        {games: games}
      end

      def empty_body
        {}
      end

      def attach_missing_venue_identity!(raw_venue, player)
        if raw_venue == 'embedded'
          venue_identities = connection.auth.venue_identities_of(token, player)
          if !venue_identities[raw_venue] && !venue_identities.empty?
            existing_venue_identity = venue_identities.values.first
            new_venue_identity = {"venue-id" => player, "name" => existing_venue_identity["name"]}
            connection.auth.attach_venue_identity_to(token, player, raw_venue, new_venue_identity)
          end
        end
      end
    end

    before do
      header('Access-Control-Allow-Origin', request.env['HTTP_ORIGIN'] || '*')

      unless authentication_exception?
        token = request.env['HTTP_AUTHORIZATION'] || params[:oauth_token]
        prevent_access! unless token
        token = token.gsub(/^Bearer\s+/, '')

        @token_owner = connection.auth.token_owner(token)
        prevent_access! unless @token_owner
      end
    end

    options '*path' do
      header('Access-Control-Allow-Headers', 'origin, x-requested-with, content-type, accept, authorization')
      header('Access-Control-Allow-Methods', 'GET, PUT, OPTIONS, POST, DELETE')
      header('Access-Control-Max-Age', '1728000')
      ""
    end

    get "public/players" do
      uuids = params[:uuids]

      venue_identities = venue_identities_for(uuids)
      venue_identities = Hash[[[uuids.first, venue_identities]]] if uuids.length == 1

      public_venue_identity_info_for(venue_identities)
    end

    get "public/:uuid" do
      uuid = params[:uuid]
      venue_identities = venue_identities_for(uuid)
      public_venue_identity_info_for(venue_identities)[uuid]
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
      owner_only!(params[:uuid])

      uuid = params[:uuid]
      venue_identities = venue_identities_for(uuid)
      {uuid: uuid, venues: venue_identities[uuid]}
    end

    # deprecated!
    get ":uuid/games" do
      player = params[:uuid]
      venue = params[:venue]

      last_updated_played_games_at = connection.cache.fetch(['last_game_registered', player, venue]) {-1}

      connection.cache.fetch(['games_i_play', player, venue, last_updated_played_games_at]) do
        get_games_for(player, venue)
      end
    end

    get ":uuid/games/friends" do
      owner_only!(params[:uuid])

      uuid = params[:uuid]
      venue = params[:venue]

      cache_buster_time = Time.now.to_i.div(60 * 60 * 2) # Time to live
      connection.cache.fetch(['games_my_friends_play', uuid, venue, cache_buster_time]) do
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
    end


    get ":player_uuid/games/:game_uuid/meta-data" do
      owner_only!(params[:player_uuid])

      player = params[:player_uuid]
      game = params[:game_uuid]
      data = try_twice_and_avoid_token_expiration do
        connection.graph.relationship_metadata(player, game, token, 'plays')
      end
      {meta: MetaData.from_graph(data)}
    end


    [":player_uuid/games/:game_uuid/meta-data", ":player_uuid/games/:game_uuid/meta-data/:property"].each do |url|
      put url do
        owner_only!(params[:player_uuid])

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
      owner_only!(params[:player_uuid])

      player = params[:player_uuid]
      game = params[:game_uuid]
      raw_venue = params[:venue]
      venue = Utils.camelize_string(raw_venue)

      connection.cache.set(['last_game_registered', player, venue], Time.now.to_i)

      connection.cache.fetch(['game_registered_v2', player, venue, game]) do
        try_twice_and_avoid_token_expiration do
          attach_missing_venue_identity!(raw_venue, player)

          connection.graph.add_role(player, token, 'player')
          response = connection.graph.add_relationship(player, game, token, 'plays', meta: {"venue#{venue}" => true})
          status response.raw.status
        end
      end
      empty_body
    end

    get ":uuid/friends" do
      owner_only!(params[:uuid])

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
      owner_only!(params[:uuid])

      friends_data = params[:friends]

      venue_id = params[:venue_id]

      cache_buster_time = Time.now
      connection.cache.fetch(['update_friends', 'v1', params[:uuid], params[:venue_id], cache_buster_time.year, cache_buster_time.month, cache_buster_time.day]) do
        Futuroscope::Future.new do
          connection = Connection.create
          friend_uuids = try_twice_and_avoid_token_expiration do
            connection.auth.uuids_of(token, venue_id => friends_data)[venue_id]
          end

          venue = Venue.const_get(Utils.camelize_string(venue_id)).new
          friend_uuids.values.each do |friend_uuid|
            try_twice_and_avoid_token_expiration do
              connection.graph.add_role(friend_uuid, token, 'player')
              venue.friend(params[:uuid], friend_uuid, token, connection)
            end
          end
        end
      end

      empty_body
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

