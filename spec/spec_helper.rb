ENV['RACK_ENV'] ||= 'test'

Bundler.require

require 'datastore-backend'
require 'auth-backend'
require 'rack/client'

require 'graph-backend'
require 'devcenter-backend'

require 'minitest/autorun'

require 'playercenter-backend'

require 'uuid'


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

DATASTORE_BACKEND = Datastore::Backend::API.new
module Devcenter::Backend
  class Connection
    alias raw_initialize initialize
    def initialize(*args)
      result = raw_initialize(*args)

      graph_adapter = Service::Client::Adapter::Faraday.new(adapter: [:rack, GRAPH_BACKEND])
      @graph.client.raw.adapter = graph_adapter

      datastore_adapter = Service::Client::Adapter::Faraday.new(adapter: [:rack, DATASTORE_BACKEND])
      @datastore.client.raw.adapter = datastore_adapter

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

      devcenter_adapter = Service::Client::Adapter::Faraday.new(adapter: [:rack, Devcenter::Backend::API.new])
      @devcenter.client.raw.adapter = devcenter_adapter

      result
    end
  end
end

def wipe_graph!
  connection = Graph::Backend::Connection.create.neo4j
  (connection.find_node_auto_index('uuid:*') || []).each do |node|
    connection.delete_node!(node)
  end
end
wipe_graph!
