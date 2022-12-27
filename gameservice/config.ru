# frozen_string_literal: true

# config.ru
require 'random_name_generator'
require 'securerandom'
require 'json'
require 'redis'
require 'newrelic_rpm'

gameredis = Redis.new(host: 'gameredis', password: 'gameredis_password')
gameredis.flushdb

# Base class for redis interface - generate key names via game_uuid and player_uuid
class MNBRedisKeys
  attr_accessor :player_uuid, :game_uuid

  def initialize(gameredis)
    @gameredis = gameredis
  end

  def game_log_key
    'game:log'
  end

  def player_name_key
    "player:name##{player_uuid}"
  end

  def game_entries_key
    "game:entries##{game_uuid}"
  end

  def open_games_list_key
    'open_games'
  end

  def running_games_list_key
    'running_games'
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

# friendly wrappers around redis api for Make Number Bigger: Microservices Edition
class MNBRedis < MNBRedisKeys
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
      @game_uuid = 'closed'
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
    @game_uuid = 'closed'
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
    @game_uuid = 'closed'
    if game_result
      @game_uuid = game_result
      attempt_join
    end
    make_new_game if game_uuid == 'closed'
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
      @game_uuid = 'closed'
    end
  end

  def monster_name
    rng = RandomNameGenerator.new(RandomNameGenerator::ROMAN)
    "#{rng.compose(3)} #{rng.compose(3)} #{rng.compose(3)}"
  rescue StandardError
    retry # sigh
  end
end

# Main base class, so everyone can just define response
class ConnectedBase
  attr_reader :env, :gamestore, :gameredis

  def initialize(gameredis)
    @gameredis = gameredis
  end

  def reset_vars
    @request = nil
  end

  def call(env)
    @env = env
    @gamestore = MNBRedis.new @gameredis
    reset_vars
    response
  end

  def request
    @request ||= Rack::Request.new @env
  end

  def open_games_list
    gameredis.llen open_games_list_key
  end
end

# Handle main game play case
class MakeNumberBiggerGame < ConnectedBase
  def response
    gamestore.game_uuid = request.params['game_uuid']
    gamestore.player_uuid = request.params['player_uuid']
    health_result = gamestore.player_turn
    [
      200,
      { 'content-type' => 'application/json' },
      [{ number: health_result, game_uuid: gamestore.game_uuid }.to_json]
    ]
  end
end

# list open games, for bigboard
class ListRunningGames < ConnectedBase
  def game_info(game_uuid)
    gamestore.game_uuid = game_uuid
    {
      boss_name: gamestore.game_name,
      number: gamestore.game_number,
      maxnumber: gamestore.game_max_number,
      players: game_players(game_uuid)
    }
  end

  def game_players(game_uuid)
    gamestore.game_uuid = game_uuid
    players = gamestore.game_players
    players.map do |p|
      gamestore.player_uuid = p
      { name: gamestore.player_name, medals: gamestore.player_medals }
    end
  end

  def response
    gamestore.cleanup_dead_games
    result = {}
    result[:games] = gamestore.running_games.map { |g| [g, game_info(g)] }.to_h
    result[:logs] = gamestore.fetch_game_log

    [
      200,
      { 'content-type' => 'application/json' },
      [result.to_json]
    ]
  end
end

# Join an existing or make a new game if there are no open games
class JoinGame < ConnectedBase
  def response
    gamestore.player_uuid = request.params['player_uuid']
    gamestore.join_existing_or_create_game
    [
      200,
      { 'content-type' => 'application/json' },
      [{ game_uuid: gamestore.game_uuid, game_name: gamestore.game_name }.to_json]
    ]
  end
end


app = Rack::Builder.app do
  map '/game/play' do
    run MakeNumberBiggerGame.new gameredis
  end
  map '/game/list' do
    run ListRunningGames.new gameredis
  end
  run JoinGame.new gameredis
end

run app
