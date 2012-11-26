require_relative '../request_spec_helper'

describe Playercenter::Backend::API do
  describe "player info" do
    it "doesn't work unauthenticated" do
      response = client.get "/v1/#{user['uuid']}"
      response.status.must_equal 403
    end

    it "doesn't work wrongly authenticated" do
      response = client.get "/v1/#{user['uuid']}", 'Authorization' => 'Bearer bla'
      response.status.must_equal 403
    end

    it "can gather information" do
      response = client.get "/v1/#{user['uuid']}", 'Authorization' => "Bearer #{token}"
      response.status.must_equal 200
      data = JSON.parse(response.body)
      data['uuid'].must_equal user['uuid']
      data['venues'].must_equal({})
    end
  end

  it "can register a player at a game" do
    game = UUID.new.generate
    connection.graph.add_role(game, token, 'game')

    connection.graph.list_roles(user['uuid'], token).wont_include 'player'
    response = client.get "/v1/#{user['uuid']}/games", 'Authorization' => "Bearer #{token}"
    games = JSON.parse(response.body)
    games.empty?.must_equal true

    response = client.post "/v1/#{user['uuid']}/games/#{game}/facebook", {'Authorization' => "Bearer #{token}"}
    response.status.must_equal 201

    connection.graph.list_roles(user['uuid'], token).must_include 'player'
    response = client.get "/v1/#{user['uuid']}/games", 'Authorization' => "Bearer #{token}"
    games = JSON.parse(response.body)
    games.size.must_equal 1
    games.must_include game
    meta = connection.graph.relationship_metadata(user['uuid'], game, token, 'plays')
    meta['venueFacebook'].must_equal true
    meta['venueGalaxySpiral'].must_be_nil

    response = client.post "/v1/#{user['uuid']}/games/#{game}/galaxy-spiral", 'Authorization' => "Bearer #{token}"
    response.status.must_equal 200

    connection.graph.list_roles(user['uuid'], token).must_include 'player'
    response = client.get "/v1/#{user['uuid']}/games", 'Authorization' => "Bearer #{token}"
    games = JSON.parse(response.body)
    games.size.must_equal 1
    games.must_include game
    meta = connection.graph.relationship_metadata(user['uuid'], game, token, 'plays')
    meta['venueFacebook'].must_equal true
    meta['venueGalaxySpiral'].must_equal true


    response = client.post "/v1/#{user['uuid']}/games/#{game}/facebook", 'Authorization' => "Bearer #{token}"
    response.status.must_equal 304

    connection.graph.list_roles(user['uuid'], token).must_include 'player'
    response = client.get "/v1/#{user['uuid']}/games", 'Authorization' => "Bearer #{token}"
    games = JSON.parse(response.body)
    games.size.must_equal 1
    games.must_include game
    meta = connection.graph.relationship_metadata(user['uuid'], game, token, 'plays')
    meta['venueFacebook'].must_equal true
    meta['venueGalaxySpiral'].must_equal true
  end

  describe "friends" do
    before do
      developers = connection.graph.uuids_by_role(app_token, 'player')
      developers.each do |developer|
        friends = connection.graph.list_related_entities(developer, app_token, 'friends')
        friends.each do |friend|
          connection.graph.remove_relationship(developer, friend, app_token, 'friends')
        end
      end
    end

    it "can list a users friends" do
      user_token1 = connection.auth.venue_token(app_token, 'facebook', 'venue-id' => '12345', 'name' => 'Sam')
      uuid1 = connection.auth.token_owner(user_token1)['uuid']

      user_token2 = connection.auth.venue_token(app_token, 'facebook', 'venue-id' => '42568', 'name' => 'Pete')
      uuid2 = connection.auth.token_owner(user_token2)['uuid']

      user_token3 = connection.auth.venue_token(app_token, 'facebook', 'venue-id' => '3497', 'name' => 'Jack')
      uuid3 = connection.auth.token_owner(user_token3)['uuid']

      connection.graph.add_relationship(uuid1, uuid2, app_token, 'friends', direction: 'both')
      connection.graph.add_relationship(uuid2, uuid3, app_token, 'friends')

      response = client.get "/v1/#{uuid1}/friends", "Authorization" => "Bearer #{user_token1}"
      response.status.must_equal 200
      friends = JSON.parse(response.body)
      friends.keys.size.must_equal 1
      friends.keys.must_include uuid2
      friends[uuid2].must_equal 'facebook' => {'id' => '42568', 'name' => 'Pete'}

      response = client.get "/v1/#{uuid2}/friends", "Authorization" => "Bearer #{user_token2}"
      response.status.must_equal 200
      friends = JSON.parse(response.body)
      friends.keys.size.must_equal 2
      friends.keys.must_include uuid1
      friends.keys.must_include uuid3

      response = client.get "/v1/#{uuid3}/friends", "Authorization" => "Bearer #{user_token3}"
      response.status.must_equal 200
      friends = JSON.parse(response.body)
      friends.keys.empty?.must_equal true
    end

    it "can update a user's friends" do
      friend_venue_data = {
        "friends" => [
          {"venue-id" => "42568", "name" => "Pete"},
          {"venue-id" => "3497", "name" => "Jack"}
        ]
      }

      user_token1 = connection.auth.venue_token(app_token, 'facebook', 'venue-id' => '12345', 'name' => 'Sam')
      uuid1 = connection.auth.token_owner(user_token1)['uuid']

      response = client.put "/v1/#{uuid1}/friends/facebook", {"Authorization" => "Bearer #{user_token1}"}, JSON.dump(friend_venue_data)
      response.status.must_equal 200

      user_token2 = connection.auth.venue_token(app_token, 'facebook', 'venue-id' => '42568', 'name' => 'Pete')
      uuid2 = connection.auth.token_owner(user_token2)['uuid']

      user_token3 = connection.auth.venue_token(app_token, 'facebook', 'venue-id' => '3497', 'name' => 'Jack')
      uuid3 = connection.auth.token_owner(user_token3)['uuid']

      response = client.get "/v1/#{uuid1}/friends", "Authorization" => "Bearer #{user_token1}"
      response.status.must_equal 200
      friends = JSON.parse(response.body)
      friends.keys.size.must_equal 2
      friends.keys.must_include uuid2
      friends.keys.must_include uuid3
    end
  end
end
