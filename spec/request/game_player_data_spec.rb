require_relative '../request_spec_helper'

describe Playercenter::Backend::API do
  describe "player/game metadata" do
    before do
      @developer = UUID.new.generate
      connection.graph.add_role(@developer, app_token, 'developer')
      game_options = {:name => "Test Game 1", :description => "Good game", :configuration => {'type' => 'html5', 'url' => 'http://example.com'},:developers => [@developer], :venues => {"spiral-galaxy" => {"enabled" => true}}, :category => 'Jump n Run'}
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
      body = JSON.dump(meta: {highscore: 100, name: "Peter", tutorialPlayed: true, someFloat: 1.234})
      headers = {'Content-Type' => 'application/json', 'Content-Length' => body.length}.merge(@auth_options)
      response = client.put "/v1/#{user['uuid']}/games/#{@game}/meta-data/", headers, body
      response.status.must_equal 200
      data = JSON.parse(response.body)
      data.must_equal("meta" => {"highscore" => 100, "name" => "Peter", "tutorialPlayed" => true, "someFloat" => 1.234})

      response = client.get "/v1/#{user['uuid']}/games/#{@game}/meta-data/", @auth_options
      data = JSON.parse(response.body)
      data.must_equal("meta" => {"highscore" => 100, "name" => "Peter", "tutorialPlayed" => true, "someFloat" => 1.234})
    end

    it "can set or update single properties" do
      body = JSON.dump(meta: {"highscore" => 100, "name" => "Peter"})
      headers = {'Content-Type' => 'application/json', 'Content-Length' => body.length}.merge(@auth_options)
      response = client.put "/v1/#{user['uuid']}/games/#{@game}/meta-data/highscore", headers, body
      response.status.must_equal 200
      data = JSON.parse(response.body)
      data.must_equal("meta" => {"highscore" => 100})

      response = client.get "/v1/#{user['uuid']}/games/#{@game}/meta-data/", @auth_options
      data = JSON.parse(response.body)
      data.must_equal("meta" => {"highscore" => 100})

      body = JSON.dump(meta: {"highscore" => 130, "name" => "Peter", "tutorialPlayed" => false})
      headers = {'Content-Type' => 'application/json', 'Content-Length' => body.length}.merge(@auth_options)
      response = client.put "/v1/#{user['uuid']}/games/#{@game}/meta-data/", headers, body
      response.status.must_equal 200
      data = JSON.parse(response.body)
      data.must_equal("meta" => {"highscore" => 130, "name" => "Peter", "tutorialPlayed" => false})

      response = client.get "/v1/#{user['uuid']}/games/#{@game}/meta-data/", @auth_options
      data = JSON.parse(response.body)
      data.must_equal("meta" => {"highscore" => 130, "name" => "Peter", "tutorialPlayed" => false})

      body = JSON.dump(meta: {"tutorialPlayed" => true})
      headers = {'Content-Type' => 'application/json', 'Content-Length' => body.length}.merge(@auth_options)
      response = client.put "/v1/#{user['uuid']}/games/#{@game}/meta-data/tutorialPlayed", headers, body
      response.status.must_equal 200
      data = JSON.parse(response.body)
      data.must_equal("meta" => {"highscore" => 130, "name" => "Peter", "tutorialPlayed" => true})

      response = client.get "/v1/#{user['uuid']}/games/#{@game}/meta-data/", @auth_options
      data = JSON.parse(response.body)
      data.must_equal("meta" => {"highscore" => 130, "name" => "Peter", "tutorialPlayed" => true})

      body = JSON.dump(meta: {"name" => "Jack"})
      headers = {'Content-Type' => 'application/json', 'Content-Length' => body.length}.merge(@auth_options)
      response = client.put "/v1/#{user['uuid']}/games/#{@game}/meta-data/highscore", headers, body
      response.status.must_equal 200
      data = JSON.parse(response.body)
      data.must_equal("meta" => {"highscore" => 130, "name" => "Peter", "tutorialPlayed" => true})

      response = client.get "/v1/#{user['uuid']}/games/#{@game}/meta-data/", @auth_options
      data = JSON.parse(response.body)
      data.must_equal("meta" => {"highscore" => 130, "name" => "Peter", "tutorialPlayed" => true})
    end

    it "can set single properties to true and then back to false" do
      body = JSON.dump(meta: {"tutorialPlayed" => true})
      headers = {'Content-Type' => 'application/json', 'Content-Length' => body.length}.merge(@auth_options)
      response = client.put "/v1/#{user['uuid']}/games/#{@game}/meta-data/tutorialPlayed", headers, body
      response.status.must_equal 200
      data = JSON.parse(response.body)
      data.must_equal("meta" => {"tutorialPlayed" => true})

      response = client.get "/v1/#{user['uuid']}/games/#{@game}/meta-data/", @auth_options
      data = JSON.parse(response.body)
      data.must_equal("meta" => {"tutorialPlayed" => true})

      body = JSON.dump(meta: {"tutorialPlayed" => false})
      headers = {'Content-Type' => 'application/json', 'Content-Length' => body.length}.merge(@auth_options)
      response = client.put "/v1/#{user['uuid']}/games/#{@game}/meta-data/tutorialPlayed", headers, body
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
        body = JSON.dump(meta: {notAllowed: [1,2,3]})
        headers = {'Content-Type' => 'application/json', 'Content-Length' => body.length}.merge(@auth_options)
        response = client.put "/v1/#{user['uuid']}/games/#{@game}/meta-data/", headers, body
        response.status.must_equal 415
      end

      it "hashes" do
        body = JSON.dump(meta: {notAllowed: {"bla" => "blub"}})
        headers = {'Content-Type' => 'application/json', 'Content-Length' => body.length}.merge(@auth_options)
        response = client.put "/v1/#{user['uuid']}/games/#{@game}/meta-data/", headers, body
        response.status.must_equal 415
      end

      it "nil" do
        body = JSON.dump(meta: {notAllowed: nil})
        headers = {'Content-Type' => 'application/json', 'Content-Length' => body.length}.merge(@auth_options)
        response = client.put "/v1/#{user['uuid']}/games/#{@game}/meta-data/", headers, body
        response.status.must_equal 415
      end
    end
  end
end