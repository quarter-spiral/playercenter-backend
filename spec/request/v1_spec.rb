require_relative '../request_spec_helper'

describe Playercenter::Backend::API do
  before do
    AUTH_HELPERS.delete_existing_users!
    AUTH_HELPERS.create_user!
  end

  describe "player info" do
    it "doesn't work unauthenticated" do
      response = client.get "/v1/#{user['uuid']}"
      response.status.must_equal 403
    end

    it "doesn't work wrongly authenticated" do
      response = client.get "/v1/#{user['uuid']}", 'Authorization' => 'Bearer bla'
      response.status.must_equal 403
    end

    describe "player informations" do
      before do
        facebook_options = {
          "venue-id" => '053324235',
          "name" =>     'Peter Smith',
          "email" =>    'peter.smith@example.com'
        }

        connection.auth.attach_venue_identity_to(token, user['uuid'], 'facebook', facebook_options)

        spiral_galaxy_options = {
          "venue-id" => '76543675',
          "name" =>     'Peter S',
          "email" =>    'peter@example.com'
        }

        connection.auth.attach_venue_identity_to(token, user['uuid'], 'spiral-galaxy', spiral_galaxy_options)
      end

      it "can be gathered with a token" do
        response = client.get "/v1/#{user['uuid']}", 'Authorization' => "Bearer #{token}"
        response.status.must_equal 200

        data = JSON.parse(response.body)

        data['uuid'].must_equal user['uuid']
        data['venues'].keys.size.must_equal 2
        data['venues']['facebook'].must_equal('name' => 'Peter Smith', 'id' => '053324235')
        data['venues']['spiral-galaxy'].must_equal('name' => 'Peter S', 'id' => '76543675')
      end

      it "can be gathered without a token" do
        response = client.get "/v1/public/#{user['uuid']}"
        response.status.must_equal 200

        data = JSON.parse(response.body)
        data['uuid'].must_equal user['uuid']
        data['venues'].keys.size.must_equal 2
        data['venues']['facebook'].must_equal('name' => 'Peter Smith')
        data['venues']['spiral-galaxy'].must_equal('name' => 'Peter S')
      end

      it "can be gathered for multiple players at once" do
        user2_options = {name: "AnotherUser", email: "another@example.com", password: "anotherpassword"}
        user2 = AUTH_HELPERS.create_user!(user2_options)
        facebook_options2 = {
          "venue-id" => '4859045',
          "name" =>     'Another User',
          "email" =>    'another@example.com'
        }
        connection.auth.attach_venue_identity_to(app_token, user2['uuid'], 'facebook', facebook_options2)

        response = client.get "/v1/public/players?uuids[]=#{user['uuid']}&uuids[]=#{user2['uuid']}"
        response.status.must_equal 200

        data = JSON.parse(response.body)
        data.keys.must_equal([user['uuid'], user2['uuid']])

        data[user['uuid']]['uuid'].must_equal user['uuid']
        data[user['uuid']]['venues'].keys.size.must_equal 2
        data[user['uuid']]['venues']['facebook'].must_equal('name' => 'Peter Smith')
        data[user['uuid']]['venues']['spiral-galaxy'].must_equal('name' => 'Peter S')

        data[user2['uuid']]['uuid'].must_equal user2['uuid']
        data[user2['uuid']]['venues'].keys.size.must_equal 1
        data[user2['uuid']]['venues']['facebook'].must_equal('name' => 'Another User')
      end

      it "always uses the batch format when hitting the batch endpoint" do
        response = client.get "/v1/public/players?uuids[]=#{user['uuid']}"
        response.status.must_equal 200

        data = JSON.parse(response.body)
        data.keys.must_equal([user['uuid']])

        data[user['uuid']]['uuid'].must_equal user['uuid']
        data[user['uuid']]['venues'].keys.size.must_equal 2
        data[user['uuid']]['venues']['facebook'].must_equal('name' => 'Peter Smith')
        data[user['uuid']]['venues']['spiral-galaxy'].must_equal('name' => 'Peter S')
      end
    end
  end

  describe "registering players at a game" do
    before do
      @developer = UUID.new.generate
      connection.graph.add_role(@developer, app_token, 'developer')

      game_options = {:name => "Test Game 1", :description => "Good game", :configuration => {'type' => 'html5', 'url' => 'http://example.com'},:developers => [@developer], :venues => {"spiral-galaxy" => {"enabled" => true}}, :category => 'Jump n Run'}
      @game = Devcenter::Backend::Game.create(app_token, game_options).uuid
    end

    it "can register a player at a game" do
      game = @game

      connection.graph.list_roles(user['uuid'], token).wont_include 'player'
      response = client.get "/v1/#{user['uuid']}/games", 'Authorization' => "Bearer #{token}"
      games = JSON.parse(response.body)['games']
      games.empty?.must_equal true

      response = client.post "/v1/#{user['uuid']}/games/#{game}/facebook", {'Authorization' => "Bearer #{token}"}
      response.status.must_equal 201

      connection.graph.list_roles(user['uuid'], token).must_include 'player'
      response = client.get "/v1/#{user['uuid']}/games", 'Authorization' => "Bearer #{token}"
      games = JSON.parse(response.body)['games']
      games.size.must_equal 1
      games.detect {|g| g['uuid'] == game}.wont_be_nil
      meta = connection.graph.relationship_metadata(user['uuid'], game, token, 'plays')
      meta['venueFacebook'].must_equal true
      meta['venueGalaxySpiral'].must_be_nil

      response = client.post "/v1/#{user['uuid']}/games/#{game}/galaxy-spiral", 'Authorization' => "Bearer #{token}"
      response.status.must_equal 200

      connection.graph.list_roles(user['uuid'], token).must_include 'player'
      response = client.get "/v1/#{user['uuid']}/games", 'Authorization' => "Bearer #{token}"
      games = JSON.parse(response.body)['games']
      games.size.must_equal 1
      games.detect {|g| g['uuid'] == game}.wont_be_nil
      meta = connection.graph.relationship_metadata(user['uuid'], game, token, 'plays')
      meta['venueFacebook'].must_equal true
      meta['venueGalaxySpiral'].must_equal true

      response = client.post "/v1/#{user['uuid']}/games/#{game}/facebook", 'Authorization' => "Bearer #{token}"
      response.status.must_equal 304

      connection.graph.list_roles(user['uuid'], token).must_include 'player'
      response = client.get "/v1/#{user['uuid']}/games", 'Authorization' => "Bearer #{token}"
      games = JSON.parse(response.body)['games']
      games.size.must_equal 1
      games.detect {|g| g['uuid'] == game}.wont_be_nil
      meta = connection.graph.relationship_metadata(user['uuid'], game, token, 'plays')
      meta['venueFacebook'].must_equal true
      meta['venueGalaxySpiral'].must_equal true
    end

    it "fills up missing venue identities when registering a player at a game" do
      facebook_options = {
        "venue-id" => '053324235',
        "name" =>     'Peter Smith',
        "email" =>    'peter.smith@example.com'
      }
      connection.auth.attach_venue_identity_to(token, user['uuid'], 'facebook', facebook_options)

      venue_identities = connection.auth.venue_identities_of(app_token, user['uuid'])
      venue_identities['embedded'].must_be_nil

      response = client.post "/v1/#{user['uuid']}/games/#{@game}/embedded", {'Authorization' => "Bearer #{token}"}
      response.status.must_equal 201
      venue_identities = connection.auth.venue_identities_of(app_token, user['uuid'])

      venue_identities['embedded'].wont_be_nil
      venue_identities['embedded']['name'].must_equal facebook_options['name']
      venue_identities['embedded']['id'].must_equal user['uuid']
    end
  end

  describe "can list player's games on a given venue" do
    {privately: '', publicly: '/public'}.each do |label, prefix|
      it "works #{label}" do
        @developer = UUID.new.generate
        connection.graph.add_role(@developer, app_token, 'developer')

        game_options1 = {:name => "Test Game 1", :description => "Good game", :configuration => {'type' => 'html5', 'url' => 'http://example.com'},:developers => [@developer], :venues => {"spiral-galaxy" => {"enabled" => true}}, :category => 'Jump n Run'}
        game1 = Devcenter::Backend::Game.create(app_token, game_options1).uuid

        game_options2 = {:name => "Test Game 2", :description => "Good game", :configuration => {'type' => 'html5', 'url' => 'http://example.com'},:developers => [@developer], :venues => {"spiral-galaxy" => {"enabled" => true}}, :category => 'Jump n Run'}
        game2 = Devcenter::Backend::Game.create(app_token, game_options2).uuid

        game_options3 = {:name => "Test Game 3", :description => "Good game", :configuration => {'type' => 'html5', 'url' => 'http://example.com'},:developers => [@developer], :venues => {"spiral-galaxy" => {"enabled" => true}}, :category => 'Jump n Run'}
        game3 = Devcenter::Backend::Game.create(app_token, game_options3).uuid

        client.post "/v1/#{user['uuid']}/games/#{game1}/facebook", 'Authorization' => "Bearer #{token}"
        client.post "/v1/#{user['uuid']}/games/#{game2}/spiral-galaxy", 'Authorization' => "Bearer #{token}"
        client.post "/v1/#{user['uuid']}/games/#{game3}/facebook", 'Authorization' => "Bearer #{token}"

        response = client.get "/v1#{prefix}/#{user['uuid']}/games?venue=facebook", {'Authorization' => "Bearer #{token}"}
        games = JSON.parse(response.body)['games']
        games.size.must_equal 2
        games.detect {|g| g['uuid'] == game1}.wont_be_nil
        games.detect {|g| g['uuid'] == game3}.wont_be_nil

        response = client.get "/v1#{prefix}/#{user['uuid']}/games?venue=spiral-galaxy", {'Authorization' => "Bearer #{token}"}
        games = JSON.parse(response.body)['games']
        games.size.must_equal 1
        games.detect {|g| g['uuid'] == game2}.wont_be_nil
      end
    end
  end
end
