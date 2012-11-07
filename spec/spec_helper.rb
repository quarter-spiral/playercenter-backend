ENV['RACK_ENV'] ||= 'test'

Bundler.require

require 'auth-backend'
require 'rack/client'

require 'graph-backend'

require 'minitest/autorun'

require 'playercenter-backend'


GRAPH_BACKEND = Graph::Backend::API.new
module Auth::Backend
  class Connection
    alias raw_initialize initialize
    def initialize(*args)
      result = raw_initialize(*args)

      graph_adapter = Service::Client::Adapter::Faraday.new(adapter: [:rack, GRAPH_BACKEND])
      @graph.client.raw.adapter = graph_adapter

      result
    end
  end
end


module Playercenter::Backend
  class Connection
    alias raw_initialize initialize
    def initialize(*args)
      result = raw_initialize(*args)

      graph_adapter = Service::Client::Adapter::Faraday.new(adapter: [:rack, GRAPH_BACKEND])
      @graph.client.raw.adapter = graph_adapter

      result
    end
  end
end

# Wipe the graph
connection = Graph::Backend::Connection.create.neo4j
(connection.find_node_auto_index('uuid:*') || []).each do |node|
  connection.delete_node!(node)
end
