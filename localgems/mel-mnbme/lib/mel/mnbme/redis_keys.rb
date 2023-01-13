# frozen_string_literal: true

module Mel
  module MNBME
    # Base class for redis interface - generate key names via game_uuid and player_uuid
    class RedisKeys
      attr_accessor :player_uuid, :game_uuid

      def initialize(gameredis)
        @gameredis = gameredis
      end

      def game_log_key
        "game:log"
      end

      def player_name_key
        "player:name##{player_uuid}"
      end

      def game_entries_key
        "game:entries##{game_uuid}"
      end

      def open_games_list_key
        "open_games"
      end

      def running_games_list_key
        "running_games"
      end

      def player_medals_key
        "player:medals##{player_uuid}"
      end

      def game_players_key
        "game:players##{game_uuid}"
      end

      def game_player_key
        "game##{game_uuid}player##{player_uuid}"
      end

      def game_name_key
        "game:name##{game_uuid}"
      end

      def game_number_key
        "game:number##{game_uuid}"
      end

      def game_max_number_key
        "game:max:number##{game_uuid}"
      end

      def game_slots_key
        "game:slots##{game_uuid}"
      end
    end
  end
end
