# frozen_string_literal: true

# config.ru
require 'random_name_generator'
require 'securerandom'
require 'json'
require 'redis'
require 'newrelic_rpm'

require "mel/mnbme"


gameredis = Redis.new(host: 'gameredis', password: 'gameredis_password')
gameredis.flushdb

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
    @gamestore = Mel::MNBME::Redis.new @gameredis
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
