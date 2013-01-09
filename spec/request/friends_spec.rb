require_relative '../request_spec_helper'

describe Playercenter::Backend::API do
  before do
    AUTH_HELPERS.delete_existing_users!
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

    describe "list a users friends" do
      before do
        @user_token1 = connection.auth.venue_token(app_token, 'facebook', 'venue-id' => '12345', 'name' => 'Sam')
        @uuid1 = connection.auth.token_owner(@user_token1)['uuid']

        @user_token2 = connection.auth.venue_token(app_token, 'facebook', 'venue-id' => '42568', 'name' => 'Pete')
        @uuid2 = connection.auth.token_owner(@user_token2)['uuid']

        @user_token3 = connection.auth.venue_token(app_token, 'facebook', 'venue-id' => '3497', 'name' => 'Jack')
        @uuid3 = connection.auth.token_owner(@user_token3)['uuid']

        @user_token4 = connection.auth.venue_token(app_token, 'facebook', 'venue-id' => '01234', 'name' => 'Zack')
        @uuid4 = connection.auth.token_owner(@user_token4)['uuid']

        @developer = UUID.new.generate
        connection.graph.add_role(@developer, app_token, 'developer')

        @game_options1 = {:name => "Test Game 1", :description => "Good game", :configuration => {'type' => 'html5', 'url' => 'http://example.com'},:developers => [@developer], :venues => {"spiral-galaxy" => {"enabled" => true}}}
        @game1 = Devcenter::Backend::Game.create(app_token, @game_options1)
        @game_options2 = {:name => "Test Game 2", :description => "Good game", :configuration => {'type' => 'html5', 'url' => 'http://example.com'},:developers => [@developer], :venues => {"spiral-galaxy" => {"enabled" => true}}}
        @game2 = Devcenter::Backend::Game.create(app_token, @game_options2)
        @game_options3 = {:name => "Test Game 3", :description => "Good game", :configuration => {'type' => 'html5', 'url' => 'http://example.com'},:developers => [@developer], :venues => {"spiral-galaxy" => {"enabled" => true}}}
        @game3 = Devcenter::Backend::Game.create(app_token, @game_options3)

        @game1 = @game1.uuid
        @game2 = @game2.uuid
        @game3 = @game3.uuid

        connection.graph.add_relationship(@uuid1, @game1, app_token, 'plays', meta: {'venueFacebook' => true, "#{MetaData::PREFIX}highScore" => 111, "#{MetaData::PREFIX}lastLevel" => "Mighty Tower"})
        connection.graph.add_relationship(@uuid2, @game1, app_token, 'plays', meta: {'venueFacebook' => true, "#{MetaData::PREFIX}highScore" => 212})
        connection.graph.add_relationship(@uuid3, @game1, app_token, 'plays', meta: {'venueFacebook' => true, "#{MetaData::PREFIX}highScore" => 313, "#{MetaData::PREFIX}lastLevel" => "Power Hall"})
        connection.graph.add_relationship(@uuid3, @game2, app_token, 'plays', meta: {'venueGalaxySpiral' => true, "#{MetaData::PREFIX}highScore" => 323, "#{MetaData::PREFIX}lastLevel" => "Arcades"})
        connection.graph.add_relationship(@uuid3, @game3, app_token, 'plays', meta: {'venueFacebook' => true, "#{MetaData::PREFIX}highScore" => 333, "#{MetaData::PREFIX}lastLevel" => "That"})
        connection.graph.add_relationship(@uuid4, @game1, app_token, 'plays', meta: {'venueFacebook' => true, 'venueGalaxySpiral' => true, "#{MetaData::PREFIX}highScore" => 414, "#{MetaData::PREFIX}lastLevel" => "Mighty Tower"})

        connection.graph.add_relationship(@uuid1, @uuid2, app_token, 'friends')
        connection.graph.add_relationship(@uuid1, @uuid4, app_token, 'friends')
        connection.graph.add_relationship(@uuid2, @uuid3, app_token, 'friends')
        connection.graph.add_relationship(@uuid4, @uuid1, app_token, 'friends')
        connection.graph.add_relationship(@uuid4, @uuid3, app_token, 'friends')
      end

      it "works for all friends" do
        response = client.get "/v1/#{@uuid1}/friends", "Authorization" => "Bearer #{@user_token1}"
        response.status.must_equal 200
        friends = JSON.parse(response.body)
        friends.keys.size.must_equal 3
        friends.keys.must_include @uuid2
        friends[@uuid2].must_equal 'facebook' => {'id' => '42568', 'name' => 'Pete'}
        friends.keys.must_include @uuid4
        friends[@uuid4].must_equal 'facebook' => {'id' => '01234', 'name' => 'Zack'}

        response = client.get "/v1/#{@uuid2}/friends", "Authorization" => "Bearer #{@user_token2}"
        response.status.must_equal 200
        friends = JSON.parse(response.body)
        friends.keys.size.must_equal 2
        friends.keys.must_include @uuid3

        response = client.get "/v1/#{@uuid3}/friends", "Authorization" => "Bearer #{@user_token3}"
        response.status.must_equal 200
        friends = JSON.parse(response.body)
        friends.keys.size.must_equal 1
        friends.keys.must_include @uuid3
      end

      it "includes the requester itself" do
        response = client.get "/v1/#{@uuid1}/friends", "Authorization" => "Bearer #{@user_token1}"
        response.status.must_equal 200
        friends = JSON.parse(response.body)
        friends.keys.size.must_equal 3
        friends.keys.must_include @uuid1
        friends[@uuid1].must_equal 'facebook' => {'id' => '12345', 'name' => 'Sam'}
      end

      it "can list friends by game" do
        response = client.get "/v1/#{@uuid4}/friends", {"Authorization" => "Bearer #{@user_token4}"}, JSON.dump(game: @game1)
        response.status.must_equal 200
        friends = JSON.parse(response.body)
        friends.keys.size.must_equal 3
        friends.keys.must_include @uuid1
        friends.keys.must_include @uuid3
        friends.keys.must_include @uuid4

        response = client.get "/v1/#{@uuid4}/friends", {"Authorization" => "Bearer #{@user_token4}"}, JSON.dump(game: @game2)
        response.status.must_equal 200
        friends = JSON.parse(response.body)
        friends.keys.size.must_equal 2
        friends.keys.must_include @uuid3
        friends.keys.must_include @uuid4
      end

      it "can add meta info to friends" do
        @user_token5 = connection.auth.venue_token(app_token, 'facebook', 'venue-id' => '723994', 'name' => 'Paul II')
        @uuid5 = connection.auth.token_owner(@user_token5)['uuid']
        connection.graph.add_relationship(@uuid5, @game1, app_token, 'plays', meta: {'venueFacebook' => true, "#{MetaData::PREFIX}lastLevel" => "Good Chamber"})
        connection.graph.add_relationship(@uuid4, @uuid5, app_token, 'friends')

        response = client.get "/v1/#{@uuid4}/friends", {"Authorization" => "Bearer #{@user_token4}"}, JSON.dump(game: @game1, meta: ['highScore'])
        response.status.must_equal 200
        friends = JSON.parse(response.body)
        friends.keys.size.must_equal 4
        friends.keys.must_include @uuid1
        friends.keys.must_include @uuid3
        friends.keys.must_include @uuid5
        friends[@uuid1]['meta'].must_equal('highScore' => 111)
        friends[@uuid3]['meta'].must_equal('highScore' => 313)
        friends[@uuid4]['meta'].must_equal('highScore' => 414)
        friends[@uuid5]['meta'].must_equal('highScore' => nil)

        response = client.get "/v1/#{@uuid4}/friends", {"Authorization" => "Bearer #{@user_token4}"}, JSON.dump(game: @game1, meta: ['highScore', 'lastLevel'])
        response.status.must_equal 200
        friends = JSON.parse(response.body)
        friends.keys.size.must_equal 4
        friends.keys.must_include @uuid1
        friends.keys.must_include @uuid3
        friends.keys.must_include @uuid5
        friends[@uuid1]['meta'].must_equal('highScore' => 111, 'lastLevel' => 'Mighty Tower')
        friends[@uuid3]['meta'].must_equal('highScore' => 313, 'lastLevel' => 'Power Hall')
        friends[@uuid4]['meta'].must_equal('highScore' => 414, 'lastLevel' => 'Mighty Tower')
        friends[@uuid5]['meta'].must_equal('highScore' => nil, 'lastLevel' => 'Good Chamber')
      end

      it "can list the games a player's friends play" do
        response = client.get "/v1/#{@uuid1}/games/friends", "Authorization" => "Bearer #{@user_token1}"
        response.status.must_equal 200
        games = JSON.parse(response.body)['games']
        games.size.must_equal 1
        games.detect {|g| g['uuid'] == @game1}.wont_be_nil

        response = client.get "/v1/#{@uuid2}/games/friends", "Authorization" => "Bearer #{@user_token2}"
        response.status.must_equal 200
        games = JSON.parse(response.body)['games']
        games.size.must_equal 3
        games.detect {|g| g['uuid'] == @game1}.wont_be_nil
        games.detect {|g| g['uuid'] == @game2}.wont_be_nil
        games.detect {|g| g['uuid'] == @game3}.wont_be_nil

        response = client.get "/v1/#{@uuid4}/games/friends", "Authorization" => "Bearer #{@user_token4}"
        response.status.must_equal 200
        games = JSON.parse(response.body)['games']
        games.size.must_equal 3
        games.detect {|g| g['uuid'] == @game1}.wont_be_nil
        games.detect {|g| g['uuid'] == @game2}.wont_be_nil
        games.detect {|g| g['uuid'] == @game3}.wont_be_nil
      end

      it "can list the games a player's friends play on a given venue" do
        response = client.get "/v1/#{@uuid1}/games/friends", {"Authorization" => "Bearer #{@user_token1}"}, JSON.dump(venue: "galaxy-spiral")
        response.status.must_equal 200
        games = JSON.parse(response.body)['games']
        games.size.must_equal 1
        games.detect {|g| g['uuid'] == @game1}.wont_be_nil

        response = client.get "/v1/#{@uuid2}/games/friends", {"Authorization" => "Bearer #{@user_token1}"}, JSON.dump(venue: "facebook")
        response.status.must_equal 200
        games = JSON.parse(response.body)['games']
        games.size.must_equal 2
        games.detect {|g| g['uuid'] == @game1}.wont_be_nil
        games.detect {|g| g['uuid'] == @game3}.wont_be_nil

        response = client.get "/v1/#{@uuid2}/games/friends", {"Authorization" => "Bearer #{@user_token2}"}, JSON.dump(venue: "galaxy-spiral")
        response.status.must_equal 200
        games = JSON.parse(response.body)['games']
        games.size.must_equal 1
        games.detect {|g| g['uuid'] == @game2}.wont_be_nil
      end
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
      friends.keys.size.must_equal 3
      friends.keys.must_include uuid1
      friends.keys.must_include uuid2
      friends.keys.must_include uuid3
    end
  end
end