require_relative '../request_spec_helper'

def gather_response(method, url, options)
  client.send(method, url, {}, options)
end

def must_be_allowed(method, url, options = {})
  response = gather_response(method, url, options)
  [200, 201].must_include response.status
end

def must_be_forbidden(method, url, options = {})
  response = gather_response(method, url, options)
  response.status.must_equal 403
end

def with_system_level_privileges
  old_token = AuthenticationInjector.token
  AuthenticationInjector.token = app_token
  yield
  AuthenticationInjector.token = old_token
end

def meta_data_must_equal(uuid, data)
  with_system_level_privileges do
    JSON.parse(client.get("/v1/#{uuid}/games/#{@game.uuid}/meta-data").body).must_equal("meta" => data)
  end
end

def must_have_friends(uuid, friends)
  with_system_level_privileges do
    friends = JSON.parse(client.get("/v1/#{uuid}/friends").body)
    friends.must_equal(friends)
  end
end

def wont_play_on_facebook(uuid, game)
  meta_data = connection.graph.relationship_metadata(uuid, game, app_token, 'plays')
  (!!meta_data['venueFacebook']).must_equal(false) if meta_data
end

def must_play_on_facebook(uuid, game)
  meta_data = connection.graph.relationship_metadata(uuid, game, app_token, 'plays')
  (!!meta_data['venueFacebook']).must_equal true
end

describe Playercenter::Backend::API do
  before do
    AUTH_HELPERS.delete_existing_users!
    AUTH_HELPERS.create_user!
    AuthenticationInjector.reset!

    @developer = UUID.new.generate
    connection.graph.add_role(@developer, app_token, 'developer')
    game_options = {:name => "Test Game 1", :description => "Good game", :configuration => {'type' => 'html5', 'url' => 'http://example.com'},:developers => [@developer], :venues => {"spiral-galaxy" => {"enabled" => true}}, :category => 'Jump n Run'}
    @game = Devcenter::Backend::Game.create(app_token, game_options)

    @user2_options = {name: "AnotherUser", email: "another@example.com", password: "anotherpassword"}
    @user2 = AUTH_HELPERS.create_user!(@user2_options)

    @user3_options = {name: "AndAnotherUser", email: "andanother@example.com", password: "andanotherpassword"}
    @user3 = AUTH_HELPERS.create_user!(@user3_options)

    @yourself = user['uuid']
    @someone_else = @user2['uuid']

    spiral_galaxy_options = {
      "venue-id" => '76543675',
      "name" =>     'Peter Smith',
      "email" =>    'peter@example.com'
    }
    connection.auth.attach_venue_identity_to(app_token, @user3['uuid'], 'spiral-galaxy', spiral_galaxy_options)

    connection.graph.add_role(@yourself, app_token, 'player')
    connection.graph.add_role(@someone_else, app_token, 'player')

    with_system_level_privileges do
      must_be_allowed :post, "/v1/#{@someone_else}/games/#{@game.uuid}/spiral-galaxy"
    end
    @friends = {"friends" => [spiral_galaxy_options]}
  end

  after do
    @game.destroy
    AuthenticationInjector.reset!
  end

  describe "unauthenticated" do
    it "can retrieve public information about a player" do
      must_be_allowed :get, "/v1/public/#{@yourself}"
    end

    it "can retrieve information about a players friends" do
      must_be_allowed :get, "/v1/public/#{@yourself}/friends"
    end

    it "can retrieve all games a player plays" do
      must_be_allowed :get, "/v1/public/#{@yourself}/games"
    end

    it "cannot retreive non-public information about a player" do
      must_be_forbidden :get, "/v1/#{@yourself}/games"
    end

    it "cannot retreive the games a user's friends play" do
      must_be_forbidden :get, "/v1/#{@yourself}/games/friends"
    end

    it "cannot retrieve a player's meta data for a game" do
      must_be_forbidden :get, "/v1/#{@yourself}/games/#{@game.uuid}/meta-data"
    end

    it "cannot set a player's meta data on a game" do
      must_be_forbidden :put, "/v1/#{@yourself}/games/#{@game.uuid}/meta-data", JSON.dump("meta" => {"bla" => "blub"})
      meta_data_must_equal(@yourself, {})

      must_be_forbidden :put, "/v1/#{@yourself}/games/#{@game.uuid}/meta-data/bla", JSON.dump("meta" => {"bla" => "blub"})
      meta_data_must_equal(@yourself, {})
    end

    it "cannot register a player at a game" do
      must_be_forbidden :post, "/v1/#{@yourself}/games/#{@game.uuid}/spiral-galaxy"
    end

    it "cannot retrieve a non-public information about a players friends" do
      must_be_forbidden :get, "/v1/#{@yourself}/friends"
    end

    it "cannot update a players friends" do
      must_be_forbidden :put, "/v1/#{@yourself}/friends/spiral-galaxy", JSON.dump(@friends)
      must_have_friends(@yourself, {})
    end
  end

  describe "authenticated as a user" do
    before do
      AuthenticationInjector.token = token
    end

    # - You can retrieve information about a player who is yourself when authenticated
    it "can retrieve information about a player who is yourself" do
      must_be_allowed :get, "/v1/#{@yourself}"
    end

    # - You cannot retrieve information about any other player without system privileges
    it "cannot retrieve information about any other player" do
      must_be_forbidden :get, "/v1/#{@someone_else}"
    end

    # - You can list the friends of a player who is yourself when authenticated
    it "can retrieve a non-public list of friends of yourself" do
      must_be_allowed :get, "/v1/#{@yourself}/friends"
    end

    # - You cannot retrieve a list of any other player's friends without system privileges
    it "cannot retrieve a non-public list of friends of anyone else" do
      must_be_forbidden :get, "/v1/#{@someone_else}/friends"
    end

    # - You can list the games friends of a player play who is yourself when authenticated
    it "can retrieve a list of games friends of yourself play" do
      must_be_allowed :get, "/v1/#{@yourself}/games/friends"
    end

    # - You cannot retrieve a list of games that the friends of any other player play without system privileges
    it "cannot retrieve a list of games friends of anyone else play" do
      must_be_forbidden :get, "/v1/#{@someone_else}/games/friends"
    end

    # - You can update the friends of a player who is yourself when authenticated
    it "can update your own friends" do
      must_be_allowed :put, "/v1/#{@yourself}/friends/spiral-galaxy", JSON.dump(@friends)
      must_have_friends(@yourself, @friends)
    end

    # - You cannot update the friends of any other player without system privileges
    it "cannot update anyone else's friends" do
      must_be_forbidden :put, "/v1/#{@someone_else}/friends/spiral-galaxy", JSON.dump(@friends)
      must_have_friends(@someone_else, {})
    end

    # - You can register a player who is yourself as a player of any game
    it "can register yourself as a player of any game" do
      wont_play_on_facebook(@yourself, @game.uuid)
      must_be_allowed :post, "/v1/#{@yourself}/games/#{@game.uuid}/facebook"
      must_play_on_facebook(@yourself, @game.uuid)
    end

    # - You cannot register any other player as the player of any game without system privileges
    it "cannot register anyone else as a player of any game" do
      wont_play_on_facebook(@someone_else, @game.uuid)

      must_be_forbidden :post, "/v1/#{@someone_else}/games/#{@game.uuid}/facebook"

      wont_play_on_facebook(@someone_else, @game.uuid)
    end

    # - You can set meta data for a player who is yourself for any game when authenticated
    it "can set meta data for yourself at any game" do
      must_be_allowed :put, "/v1/#{@yourself}/games/#{@game.uuid}/meta-data", JSON.dump("meta" => {"bla" => "blub"})
      meta_data_must_equal(@yourself, {"bla" => "blub"})

      must_be_allowed :put, "/v1/#{@yourself}/games/#{@game.uuid}/meta-data/bla", JSON.dump("meta" => {"bla" => "blub2"})
      meta_data_must_equal(@yourself, {"bla" => "blub2"})
    end

    # - You cannot set meta data for any other player on any game without system privileges
    it "cannot set meta data for anyone else at any game" do
      must_be_forbidden :put, "/v1/#{@someone_else}/games/#{@game.uuid}/meta-data", JSON.dump("meta" => {"bla" => "blub"})
      meta_data_must_equal(@someone_else, {})

      must_be_forbidden :put, "/v1/#{@someone_else}/games/#{@game.uuid}/meta-data/bla", JSON.dump("meta" => {"bla" => "blub2"})
      meta_data_must_equal(@someone_else, {})
    end

    # - You can retrieve meta data for any game for a player who is yourself when authenticated
    it "can retrieve meta data from yourself from any game" do
      must_be_allowed :get, "/v1/#{@yourself}/games/#{@game.uuid}/meta-data"
    end

    # - You cannot retrieve meta data for any other player for any game without system privileges
    it "cannot retrieve meta data from anyone else from any game" do
      must_be_forbidden :get, "/v1/#{@someone_else}/games/#{@game.uuid}/meta-data"
    end
  end

  describe "authenticated as an app with system level privileges" do
    before do
      AuthenticationInjector.token = app_token
    end

    it "can retrieve information about any player" do
      must_be_allowed :get, "/v1/#{@someone_else}"
    end

    it "can retrieve a non-public list of friends of anyone" do
      must_be_allowed :get, "/v1/#{@someone_else}/friends"
    end

    it "can retrieve a list of games friends of any player play" do
      must_be_allowed :get, "/v1/#{@someone_else}/games/friends"
    end

    it "can update any player's friends" do
      must_be_allowed :put, "/v1/#{@someone_else}/friends/spiral-galaxy", JSON.dump(@friends)
      must_have_friends(@someone_else, @friends)
    end

    it "can register any player as a player of any game" do
      wont_play_on_facebook(@someone_else, @game.uuid)

      must_be_allowed :post, "/v1/#{@someone_else}/games/#{@game.uuid}/facebook"

      must_play_on_facebook(@someone_else, @game.uuid)
    end

    it "can set meta data for any player at any game" do
      must_be_allowed :put, "/v1/#{@someone_else}/games/#{@game.uuid}/meta-data", JSON.dump("meta" => {"bla" => "blub"})
      meta_data_must_equal(@someone_else, {"bla" => "blub"})

      must_be_allowed :put, "/v1/#{@someone_else}/games/#{@game.uuid}/meta-data/bla", JSON.dump("meta" => {"bla" => "blub2"})
      meta_data_must_equal(@someone_else, {"bla" => "blub2"})
    end

    it "can retrieve meta data from yourself from any game" do
      must_be_allowed :get, "/v1/#{@someone_else}/games/#{@game.uuid}/meta-data"
    end
  end
end