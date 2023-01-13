# frozen_string_literal: true
require_relative "mnbme/version"
require_relative "mnbme/redis_keys"
require_relative "mnbme/game_management"
require_relative "mnbme/redis"

module Mel
  module MNBME
    class Error < StandardError; end
  end
end
