# config.ru
require 'random_name_generator'
require 'securerandom'
require 'json'
require 'redis'

module MNBKeys
  def player_name_key(player_uuid)
    "player:name##{ player_uuid }"
  end

  def game_entries_key(game_uuid)
    "game:entries##{ game_uuid }"
  end

  def open_games_list_key
    "open_games"
  end

  def running_games_list_key
    "running_games"
  end

  def game_players_key(game_uuid)
    "game:players##{ game_uuid }"
  end

  def game_player_key(game_uuid, player_uuid)
    "game##{ game_uuid }player##{ player_uuid }"
  end

  def game_name_key(game_uuid)
    "game:name##{ game_uuid }"
  end

  def game_number_key(game_uuid)
    return "game:number##{ game_uuid }"
  end

  def game_max_number_key(game_uuid)
    return "game:max:number##{ game_uuid }"
  end

  def game_slots_key(game_uuid)
    "game:slots##{ game_uuid }"
  end
end

class RedisConnectedBase
  attr_reader :redis
  attr_reader :request
  attr_reader :env

  include MNBKeys

  def reset_vars
    @request = nil
    @game_uuid = nil
    @player_uuid = nil
    @redis = nil
    @redis_used = false
  end
  def call(env)
    @env = env
    reset_vars
    resp = response
    redis.close if @redis_used
    resp
  end

  def request
    @request ||= Rack::Request.new @env
  end

  def game_uuid
    request.params["game_uuid"]
  end

  def player_uuid
    request.params["player_uuid"]
  end

  def redis
    @redis_used = true
    @redis ||= Redis.new(host: "gameredis", password: "gameredis_password")
  end

  def open_games_list
    redis.llen
  end
end

class MakeNumberBiggerGame < RedisConnectedBase
  def do_turn
    @game_uuid = request.params["game_uuid"]
    @health_result = redis.decr game_number_key(@game_uuid)
    if @health_result == 0
      # we got the killing blow!  shut the game down.
      redis.lrem running_games_list_key, -1, @game_uuid
      @game_uuid = "closed"
    elsif @health_result < 0
      @game_uuid = "closed"
    end
  end
  def response
    do_turn
    puts "#{@game_uuid} -> tick(#{@health_result})"
    [
      200,
      { "content-type" => "application/json" },
      [ {number: @health_result, game_uuid: @game_uuid}.to_json ]
    ]
  end
end

class ListRunningGames < RedisConnectedBase
  def response
    games = redis.lrange running_games_list_key, 0, -1
    result = {}
    games.each do |g|
      players_list = []
      result[g] = {boss_name: '', number: 0, maxnumber: 0, players: players_list}
      result[g][:boss_name] = redis.get game_name_key(g)
      result[g][:number] = redis.get game_number_key(g)
      result[g][:maxnumber] = redis.get game_max_number_key(g)
      players = redis.lrange game_players_key(g), 0, -1
      players.each do |p|
        players_list << redis.get(player_name_key(p))
      end
    end
    [
      200,
      { "content-type" => "application/json" },
      [ result.to_json ]
    ]
  end
end

class JoinGame < RedisConnectedBase
  def monster_name
    rng = RandomNameGenerator.new(RandomNameGenerator::ROMAN)
    "#{rng.compose(3)} #{rng.compose(3)} #{rng.compose(3)}"
  rescue
    retry # sigh
  end
  def make_new_game
    @game_uuid = SecureRandom.uuid
    puts "player #{player_uuid} Making a new game #{@game_uuid}"
    redis.set game_name_key(@game_uuid), monster_name
    redis.set game_number_key(@game_uuid), 20 # low numbers to start
    redis.set game_max_number_key(@game_uuid), 20 # low numbers to start
    redis.set game_entries_key(@game_uuid), 20 # low numbers to start
    redis.lpush open_games_list_key, @game_uuid
    redis.lpush running_games_list_key, @game_uuid
    redis.lpush game_players_key(@game_uuid), player_uuid
    puts "Finished making new game #{@game_uuid}"
  end
  def join_existing_game
    game_result = redis.lpop open_games_list_key
    if game_result
      puts "player #{player_uuid} Joining existing game #{game_result}"
      @game_uuid = game_result
      join_tickets = redis.decr game_entries_key(@game_uuid)
      puts "Working with result - #{join_tickets} (game_uuid: #{@game_uuid})"
      if join_tickets > 0
        puts "puts DISP - stillopen"
        puts "redis.lpush #{open_games_list_key} #{@game_uuid}"
        redis.lpush open_games_list_key, @game_uuid
        redis.lpush game_players_key(@game_uuid), player_uuid
      else
        puts "DISP - closed"
        @game_uuid = "closed"
      end
    end
  end
  def response
    join_existing_game
    make_new_game unless @game_uuid == "closed"
    [
      200,
      { "content-type" => "application/json" },
      [ {game_uuid: @game_uuid}.to_json ]
    ]
  end
end

redis = Redis.new(host: "gameredis", password: "gameredis_password")
redis.flushdb
redis.close

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
