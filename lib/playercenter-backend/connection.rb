module Playercenter::Backend
  class Connection
    attr_reader :auth, :graph

    def self.create
      new(
        ENV['QS_AUTH_BACKEND_URL'] || 'http://auth-backend.dev',
        ENV['QS_GRAPH_BACKEND_URL'] || 'http://graph-backend.dev'
      )
    end

    def initialize(auth_backend_url, graph_backend_url)
      @auth = Auth::Client.new(auth_backend_url)
      @graph = Graph::Client.new(graph_backend_url)
    end
  end
end
