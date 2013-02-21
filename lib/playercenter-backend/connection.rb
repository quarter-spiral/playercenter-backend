module Playercenter::Backend
  class Connection
    attr_reader :auth, :graph, :devcenter, :cache

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
      @cache = ::Cache::Client.new(::Cache::Backend::IronCache, ENV['IRON_CACHE_PROJECT_ID'], ENV['IRON_CACHE_TOKEN'], ENV['IRON_CACHE_CACHE'])
    end
  end
end