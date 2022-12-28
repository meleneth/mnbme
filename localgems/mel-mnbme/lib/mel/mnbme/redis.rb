require_relative "redis_keys"
require_relative "game_management"

module Mel
  module MNBME
    # friendly wrappers around redis api for Make Number Bigger: Microservices Edition
    class Redis < RedisKeys
      attr_reader :gameredis

      include GameManagement

      def game_name
        gameredis.get game_name_key
      end

      def game_number
        gameredis.get game_number_key
      end

      def game_max_number
        gameredis.get game_max_number_key
      end

      def game_players
        gameredis.lrange game_players_key, 0, -1
      end

      def player_turn
        unless running_games.include? game_uuid
          @game_uuid = "closed"
          return 0
        end
        health = deal_a_savage_blow
        refresh_game_expiration
        check_health_conditions(health)
        health
      end

      def check_health_conditions(health)
        if health.zero?
          award_medal
          game_log "#{player_name} has vanquished #{monster_name} and now has #{player_medals} medals"
          shutdown_game
        end
        return unless health.negative?

        cleanup_dead_game
        @game_uuid = "closed"
      end

      def deal_a_savage_blow
        gameredis.decr game_number_key
      end

      def refresh_game_expiration
        gameredis.expire game_number_key, 10
      end

      def take_join_ticket
        gameredis.decr game_entries_key
      end

      def add_player_to_game
        gameredis.lpush game_players_key, player_uuid
      end

      def join_existing_or_create_game
        game_result = first_open_game
        @game_uuid = "closed"
        if game_result
          @game_uuid = game_result
          attempt_join
        end
        make_new_game if game_uuid == "closed"
      end

      def player_name
        gameredis.get player_name_key
      end

      def player_medals
        gameredis.get player_medals_key
      end

      def shutdown_game
        cleanup_dead_game
      end

      def first_open_game
        gameredis.lpop open_games_list_key
      end

      def award_medal
        gameredis.incr player_medals_key
      end

      def game_log(message)
        gameredis.lpush game_log_key, message
        gameredis.ltrim game_log_key, 0, 99
      end

      def fetch_game_log
        gameredis.lrange game_log_key, 0, -1
      end

      def running_games
        gameredis.lrange running_games_list_key, 0, -1
      end

      private

      def attempt_join
        if take_join_ticket.positive?
          add_game_to_open_list
          add_player_to_game
        else
          @game_uuid = "closed"
        end
      end

      def monster_name
        rng = RandomNameGenerator.new(RandomNameGenerator::ROMAN)
        "#{rng.compose(3)} #{rng.compose(3)} #{rng.compose(3)}"
      rescue
        retry # sigh
      end
    end
  end
end
