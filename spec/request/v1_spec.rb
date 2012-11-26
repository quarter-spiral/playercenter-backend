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
end
