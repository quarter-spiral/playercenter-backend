require_relative '../request_spec_helper'

describe Playercenter::Backend::API do
  describe "player/game metadata" do
    before do
      @developer = UUID.new.generate
      connection.graph.add_role(@developer, app_token, 'developer')
      game_options = {:name => "Test Game 1", :description => "Good game", :configuration => {'type' => 'html5', 'url' => 'http://example.com'},:developers => [@developer], :venues => {"spiral-galaxy" => {"enabled" => true}}}
      @game = Devcenter::Backend::Game.create(app_token, game_options).uuid
      @auth_options = {'Authorization' => "Bearer #{token}"}
      client.post "/v1/#{user['uuid']}/games/#{@game}/facebook", @auth_options
    end

    it "is an empty hash by default" do
      response = client.get "/v1/#{user['uuid']}/games/#{@game}/meta-data/", @auth_options
      data = JSON.parse(response.body)
      data.must_equal("meta" => {})
    end

    it "can be set and retrieved" do
      response = client.put "/v1/#{user['uuid']}/games/#{@game}/meta-data/", @auth_options, JSON.dump(meta: {highscore: 100, name: "Peter", tutorialPlayed: true, someFloat: 1.234})
      response.status.must_equal 200
      data = JSON.parse(response.body)
      data.must_equal("meta" => {"highscore" => 100, "name" => "Peter", "tutorialPlayed" => true, "someFloat" => 1.234})

      response = client.get "/v1/#{user['uuid']}/games/#{@game}/meta-data/", @auth_options
      data = JSON.parse(response.body)
      data.must_equal("meta" => {"highscore" => 100, "name" => "Peter", "tutorialPlayed" => true, "someFloat" => 1.234})
    end

    it "can set or update single properties" do
      response = client.put "/v1/#{user['uuid']}/games/#{@game}/meta-data/highscore", @auth_options, JSON.dump(meta: {"highscore" => 100, "name" => "Peter"})
      response.status.must_equal 200
      data = JSON.parse(response.body)
      data.must_equal("meta" => {"highscore" => 100})

      response = client.get "/v1/#{user['uuid']}/games/#{@game}/meta-data/", @auth_options
      data = JSON.parse(response.body)
      data.must_equal("meta" => {"highscore" => 100})

      response = client.put "/v1/#{user['uuid']}/games/#{@game}/meta-data/", @auth_options, JSON.dump(meta: {"highscore" => 130, "name" => "Peter", "tutorialPlayed" => false})
      response.status.must_equal 200
      data = JSON.parse(response.body)
      data.must_equal("meta" => {"highscore" => 130, "name" => "Peter", "tutorialPlayed" => false})

      response = client.get "/v1/#{user['uuid']}/games/#{@game}/meta-data/", @auth_options
      data = JSON.parse(response.body)
      data.must_equal("meta" => {"highscore" => 130, "name" => "Peter", "tutorialPlayed" => false})

      response = client.put "/v1/#{user['uuid']}/games/#{@game}/meta-data/tutorialPlayed", @auth_options, JSON.dump(meta: {"tutorialPlayed" => true})
      response.status.must_equal 200
      data = JSON.parse(response.body)
      data.must_equal("meta" => {"highscore" => 130, "name" => "Peter", "tutorialPlayed" => true})

      response = client.get "/v1/#{user['uuid']}/games/#{@game}/meta-data/", @auth_options
      data = JSON.parse(response.body)
      data.must_equal("meta" => {"highscore" => 130, "name" => "Peter", "tutorialPlayed" => true})

      response = client.put "/v1/#{user['uuid']}/games/#{@game}/meta-data/highscore", @auth_options, JSON.dump(meta: {"name" => "Jack"})
      response.status.must_equal 200
      data = JSON.parse(response.body)
      data.must_equal("meta" => {"highscore" => 130, "name" => "Peter", "tutorialPlayed" => true})

      response = client.get "/v1/#{user['uuid']}/games/#{@game}/meta-data/", @auth_options
      data = JSON.parse(response.body)
      data.must_equal("meta" => {"highscore" => 130, "name" => "Peter", "tutorialPlayed" => true})
    end

    it "can set single properties to true and then back to false" do
      response = client.put "/v1/#{user['uuid']}/games/#{@game}/meta-data/tutorialPlayed", @auth_options, JSON.dump(meta: {"tutorialPlayed" => true})
      response.status.must_equal 200
      data = JSON.parse(response.body)
      data.must_equal("meta" => {"tutorialPlayed" => true})

      response = client.get "/v1/#{user['uuid']}/games/#{@game}/meta-data/", @auth_options
      data = JSON.parse(response.body)
      data.must_equal("meta" => {"tutorialPlayed" => true})

      response = client.put "/v1/#{user['uuid']}/games/#{@game}/meta-data/tutorialPlayed", @auth_options, JSON.dump(meta: {"tutorialPlayed" => false})
      response.status.must_equal 200
      data = JSON.parse(response.body)
      data.must_equal("meta" => {"tutorialPlayed" => false})

      response = client.get "/v1/#{user['uuid']}/games/#{@game}/meta-data/", @auth_options
      data = JSON.parse(response.body)
      data.must_equal("meta" => {"tutorialPlayed" => false})
    end

    describe "does not allow" do
      after do
        response = client.get "/v1/#{user['uuid']}/games/#{@game}/meta-data/", @auth_options
        data = JSON.parse(response.body)
        data.must_equal("meta" => {})
      end

      it "arrays" do
        response = client.put "/v1/#{user['uuid']}/games/#{@game}/meta-data/", @auth_options, JSON.dump(meta: {notAllowed: [1,2,3]})
        response.status.must_equal 415
      end

      it "hashes" do
        response = client.put "/v1/#{user['uuid']}/games/#{@game}/meta-data/", @auth_options, JSON.dump(meta: {notAllowed: {"bla" => "blub"}})
        response.status.must_equal 415
      end

      it "nil" do
        response = client.put "/v1/#{user['uuid']}/games/#{@game}/meta-data/", @auth_options, JSON.dump(meta: {notAllowed: nil})
        response.status.must_equal 415
      end
    end
  end
end