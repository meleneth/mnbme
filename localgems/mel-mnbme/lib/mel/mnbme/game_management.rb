module Mel
  module MNBME
    # GameRedis GameManagement bits
    module GameManagement
      def cleanup_dead_games
        running_games.each do |g|
          @game_uuid = g
          unless game_exists?
            game_log "Sending in the janitor after #{game_uuid}"
            cleanup_dead_game
          end
        end
      end

      def add_game_to_open_list
        gameredis.lpush open_games_list_key, game_uuid
      end

      def game_exists?
        g = gameredis.exists game_number_key
        g != 0
      end

      def make_new_game
        @game_uuid = SecureRandom.uuid
        set_new_game_counters
        add_new_game_to_lists
        gameredis.expire game_number_key, 10
        game_log "#{player_name} has discovered #{monster_name}"
      end

      def add_new_game_to_lists
        gameredis.lpush open_games_list_key, game_uuid
        gameredis.lpush running_games_list_key, game_uuid
        gameredis.lpush game_players_key, player_uuid
      end

      def set_new_game_counters
        gameredis.set game_name_key, monster_name
        gameredis.set game_number_key, 100 # low numbers to start
        gameredis.set game_max_number_key, 100 # low numbers to start
        gameredis.set game_entries_key, 5 # low numbers to start
      end

      def cleanup_dead_game
        gameredis.del game_name_key, game_number_key, game_max_number_key, game_entries_key, game_players_key
        gameredis.lrem running_games_list_key, -1, game_uuid
        gameredis.lrem open_games_list_key, -1, game_uuid
      end
    end
  end
end
