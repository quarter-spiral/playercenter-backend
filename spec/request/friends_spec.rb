require_relative '../request_spec_helper'

describe Playercenter::Backend::API do
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

        connection.graph.add_relationship(@uuid1, @uuid2, app_token, 'friends', direction: 'both')
        connection.graph.add_relationship(@uuid2, @uuid3, app_token, 'friends')
        connection.graph.add_relationship(@uuid2, @uuid4, app_token, 'friends')


        @game1 = UUID.new.generate
        connection.graph.add_role(@game1, app_token, 'game')
        @game2 = UUID.new.generate
        connection.graph.add_role(@game2, app_token, 'game')

        connection.graph.add_relationship(@uuid1, @game1, app_token, 'plays')
        connection.graph.add_relationship(@uuid2, @game1, app_token, 'plays')
        connection.graph.add_relationship(@uuid3, @game2, app_token, 'plays')
        connection.graph.add_relationship(@uuid4, @game1, app_token, 'plays')
      end

      it "works for all friends" do
        response = client.get "/v1/#{@uuid1}/friends", "Authorization" => "Bearer #{@user_token1}"
       response.status.must_equal 200
        friends = JSON.parse(response.body)
        friends.keys.size.must_equal 1
        friends.keys.must_include @uuid2
        friends[@uuid2].must_equal 'facebook' => {'id' => '42568', 'name' => 'Pete'}

        response = client.get "/v1/#{@uuid2}/friends", "Authorization" => "Bearer #{@user_token2}"
        response.status.must_equal 200
        friends = JSON.parse(response.body)
        friends.keys.size.must_equal 3
        friends.keys.must_include @uuid1
        friends.keys.must_include @uuid3
        friends.keys.must_include @uuid4

        response = client.get "/v1/#{@uuid3}/friends", "Authorization" => "Bearer #{@user_token3}"
        response.status.must_equal 200
        friends = JSON.parse(response.body)
        friends.keys.empty?.must_equal true
      end

      it "can list friends by game" do
        response = client.get "/v1/#{@uuid2}/friends", {"Authorization" => "Bearer #{@user_token1}"}, JSON.dump(game: @game1)
       response.status.must_equal 200
        friends = JSON.parse(response.body)
        friends.keys.size.must_equal 2
        friends.keys.must_include @uuid1
        friends.keys.must_include @uuid4

        response = client.get "/v1/#{@uuid2}/friends", {"Authorization" => "Bearer #{@user_token1}"}, JSON.dump(game: @game2)
       response.status.must_equal 200
        friends = JSON.parse(response.body)
        friends.keys.size.must_equal 1
        friends.keys.must_include @uuid3
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
      friends.keys.size.must_equal 2
      friends.keys.must_include uuid2
      friends.keys.must_include uuid3
    end
  end
end
