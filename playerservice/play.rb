#!/usr/bin/env ruby
# frozen_string_literal: true

require 'random_name_generator'
require 'faraday'
require 'json'
require 'newrelic_rpm'

def get_name
  rng = RandomNameGenerator.new(RandomNameGenerator::ELVEN)
  "#{rng.compose(3)} #{rng.compose(3)}"
rescue StandardError
  retry # sigh
end

name = get_name

accountservice = Faraday.new(url: 'http://accountservice:9292') do |f|
  f.response :json, parser_options: { symbolize_names: true }
end

gameservice = Faraday.new(url: 'http://gameservice:9292') do |f|
  f.response :json, parser_options: { symbolize_names: true }
end

puts "Registering #{name} with Account Service"

response = accountservice.post('/login', URI.encode_www_form({ name: name }))
player_uuid = response.body[:player_uuid]
puts "From accountservice we got #{player_uuid}"

game_uuid = 'closed'
loop do
  if game_uuid == 'closed'
    response = gameservice.post('/game/join', URI.encode_www_form({ player_uuid: player_uuid }))
    if response.success?
      game_uuid = response.body[:game_uuid]
      game_name = response.body[:game_name]
      puts "Joined game - #{game_uuid} - #{game_name}"
    else
      puts 'Error joining game'
    end
  end
  if game_uuid != 'closed'
    # puts "post /game/play #{ game_uuid }"
    response = gameservice.post('/game/play', URI.encode_www_form({ player_uuid: player_uuid, game_uuid: game_uuid }))
    body = response.body
    game_uuid = body[:game_uuid]
    number = body[:number]
    # puts "#{name}->tick(#{number}) for game # #{game_uuid}"
  else
    puts 'Game was closed, did nothing'
  end
  sleep 1
end
