module Playercenter::Backend
  class Connection
    attr_reader :auth, :graph, :devcenter

    def self.create
      new(
        ENV['QS_AUTH_BACKEND_URL'] || 'http://auth-backend.dev',
        ENV['QS_GRAPH_BACKEND_URL'] || 'http://graph-backend.dev',
        ENV['QS_DEVCENTER_BACKEND_URL'] || 'http://devcenter-backend.dev'
      )
    end

    def initialize(auth_backend_url, graph_backend_url, devcenter_backend_url)
      @auth = Auth::Client.new(auth_backend_url)
      @graph = Graph::Client.new(graph_backend_url)
      @devcenter = Devcenter::Client.new(devcenter_backend_url)
    end
  end
end
