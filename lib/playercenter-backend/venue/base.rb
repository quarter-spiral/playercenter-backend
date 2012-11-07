module Playercenter::Backend::Venue
  class Base
    def friend(uuid1, uuid2, token, connection)
      connection.graph.add_relationship(uuid1, uuid2, token, 'friends', 'direction' => direction)
    end

    protected
    def direction
      "outgoing"
    end
  end
end
