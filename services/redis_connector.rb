# frozen_string_literal: true

# Singleton class that checks if
# a Redis instance is alive and provide
# a single point of connection to redis
#:nodoc: all
module EasyMonitor
  module Util
    module Connectors
      require 'singleton'
      require 'redis'

      class RedisConnector
        include Singleton

        attr_reader :connection

        def initialize
          @connection = new_connection
        end

        def ping
          @connection.ping
        end

        private

        # Using the default configuration but this could
        # be extended by using a default config file
        def new_connection
          Redis.new
        end
      end
    end
  end
end
