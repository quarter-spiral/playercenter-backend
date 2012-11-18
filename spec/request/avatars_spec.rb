require_relative '../request_spec_helper'

describe Playercenter::Backend::API do
  describe "Avatar retrieval" do
    describe "on facebook" do
      it "redirects to the facebook avatar endpoint" do
        facebook_id = '768942708'
        token = connection.auth.venue_token(app_token, 'facebook', 'name' => 'Peter Smith', 'venue-id' => facebook_id)
        user = connection.auth.token_owner(token)

        response = client.get "/v1/#{user['uuid']}/avatars/facebook"
        response.status.must_equal 302
        response.headers['Location'].must_equal "https://graph.facebook.com/#{facebook_id}/picture"
      end
    end
  end
end
