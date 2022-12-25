# config.ru
require 'random_name_generator'
require 'securerandom'
require 'json'
require 'redis'
require 'newrelic_rpm'

class MNBRedis
  attr_accessor :player_uuid
  attr_accessor :game_uuid

  def redis
    @redis_used = true
    @redis ||= Redis.new(host: "gameredis", password: "gameredis_password")
  end
  def close
    if @redis_used
      @redis.close
      @redis_used = false
    end
  end
  def add_game_to_open_list
    redis.lpush open_games_list_key, game_uuid
  end
  def game_name
    redis.get game_name_key
  end
  def game_number
    redis.get game_number_key
  end
  def game_max_number
    redis.get game_max_number_key
  end
  def game_players
    redis.lrange game_players_key, 0, -1
  end
  def player_turn
    if not running_games.include? game_uuid
      @game_uuid = "closed"
      return 0
    end
    health = redis.decr game_number_key
    if health == 0
      award_medal
      game_log "#{player_name} has vanquished #{monster_name} and now has #{player_medals} medals"
      shutdown_game
    end
    health
  end
  def take_join_ticket
    redis.decr game_entries_key
  end
  def add_player_to_game
    redis.lpush game_players_key, player_uuid
  end
  def join_existing_or_create_game
    game_result = first_open_game
    @game_uuid = "closed"
    if game_result
      @game_uuid = game_result
      if take_join_ticket > 0
        add_game_to_open_list
        add_player_to_game
      else
        @game_uuid = "closed"
      end
    end
    make_new_game if game_uuid == "closed"
  end
  def player_name
    redis.get player_name_key
  end
  def player_medals
    redis.get player_medals_key
  end
  def shutdown_game
    redis.lrem running_games_list_key, -1, game_uuid
  end
  def first_open_game
    redis.lpop open_games_list_key
  end
  def award_medal
    redis.incr player_medals_key
  end
  def make_new_game
    @game_uuid = SecureRandom.uuid
    redis.set game_name_key, monster_name
    redis.set game_number_key, 100 # low numbers to start
    redis.set game_max_number_key, 100 # low numbers to start
    redis.set game_entries_key, 5 # low numbers to start
    redis.lpush open_games_list_key, game_uuid
    redis.lpush running_games_list_key, game_uuid
    redis.lpush game_players_key, player_uuid
    game_log "#{ player_name } has discovered #{ monster_name }"
  end
  def game_log message
    redis.lpush game_log_key, message
    redis.ltrim game_log_key, 0, 99
  end
  def get_game_log
    redis.lrange game_log_key, 0, -1
  end
  def running_games
    redis.lrange running_games_list_key, 0, -1
  end
  private
  def monster_name
    rng = RandomNameGenerator.new(RandomNameGenerator::ROMAN)
    "#{rng.compose(3)} #{rng.compose(3)} #{rng.compose(3)}"
  rescue
    retry # sigh
  end
  def game_log_key
    'game:log'
  end
  def player_name_key
    "player:name##{ player_uuid }"
  end
  def game_entries_key
    "game:entries##{ game_uuid }"
  end
  def open_games_list_key
    "open_games"
  end
  def running_games_list_key
    "running_games"
  end
  def player_medals_key
    "player:medals##{ player_uuid }"
  end
  def game_players_key
    "game:players##{ game_uuid }"
  end
  def game_player_key
    "game##{ game_uuid }player##{ player_uuid }"
  end
  def game_name_key
    "game:name##{ game_uuid }"
  end
  def game_number_key
    return "game:number##{ game_uuid }"
  end
  def game_max_number_key
    return "game:max:number##{ game_uuid }"
  end
  def game_slots_key
    "game:slots##{ game_uuid }"
  end
end

class ConnectedBase
  attr_reader :request
  attr_reader :env
  attr_reader :gamestore

  def reset_vars
    @request = nil
  end
  def call(env)
    @env = env
    @gamestore = MNBRedis.new
    reset_vars
    resp = response
    resp
  end
  def request
    @request ||= Rack::Request.new @env
  end
  def open_games_list
    redis.llen
  end
end

class MakeNumberBiggerGame < ConnectedBase
  def response
    gamestore.game_uuid = request.params["game_uuid"]
    gamestore.player_uuid = request.params["player_uuid"]
    health_result = gamestore.player_turn
    [
      200,
      { "content-type" => "application/json" },
      [ {number: health_result, game_uuid: gamestore.game_uuid}.to_json ]
    ]
  end
end

class ListRunningGames < ConnectedBase
  def response
    games = gamestore.running_games
    result = {}
    result[:games] = {}
    result[:logs] = gamestore.get_game_log
    games.each do |g|
      players_list = []
      gameinfo = {
        boss_name: '',
        number: 0,
        maxnumber: 0,
        players: players_list
      }
      result[:games][g] = gameinfo
      gamestore.game_uuid = g
      gameinfo[:boss_name] = gamestore.game_name
      gameinfo[:number] = gamestore.game_number
      gameinfo[:maxnumber] = gamestore.game_max_number
      players = gamestore.game_players
      players.each do |p|
        gamestore.player_uuid = p
        players_list << {name: gamestore.player_name, medals: gamestore.player_medals}
      end
    end
    [
      200,
      { "content-type" => "application/json" },
      [ result.to_json ]
    ]
  end
end

class JoinGame < ConnectedBase
  def response
    gamestore.player_uuid = request.params["player_uuid"]
    gamestore.join_existing_or_create_game
    [
      200,
      { "content-type" => "application/json" },
      [ { game_uuid: gamestore.game_uuid, game_name: gamestore.game_name }.to_json ]
    ]
  end
end

redis = Redis.new(host: "gameredis", password: "gameredis_password")
redis.flushdb

app = Rack::Builder.app do
  map '/game/play' do
    run MakeNumberBiggerGame.new
  end
  map '/game/list' do
    run ListRunningGames.new
  end
  run JoinGame.new
end

run app
