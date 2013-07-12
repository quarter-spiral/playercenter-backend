module Playercenter
  module Backend
    # Your code goes here...
  end
end

require "playercenter-backend/version"
require "playercenter-backend/utils"
require "playercenter-backend/error"
require "playercenter-backend/meta_data"
require "playercenter-backend/venue"
require "playercenter-backend/connection"
require "playercenter-backend/api"

require "auth-client"
require "graph-client"
require "devcenter-client"
require "cache-client"
require "cache-backend-iron-cache"
require "futuroscope"
