#!/usr/bin/env ruby

require 'random_name_generator'
require 'faraday'
require 'json'

rng = RandomNameGenerator.new
name = "#{rng.compose(3)} #{rng.compose(3)}"

accountservice = Faraday.new(url: 'http://accountservice:9292') do |f|
  f.response :json, parser_options: {symbolize_names: true}
end

gameservice = Faraday.new(url: 'http://gameservice:9292') do |f|
  f.response :json, parser_options: {symbolize_names: true}
end

puts "Registering #{name} with Account Service"

response = accountservice.post("/login", URI.encode_www_form({name: name}))
player_uuid = response.body[:player_uuid]
puts "From accountservice we got #{player_uuid}"

game_uuid = "closed"
loop do
  if game_uuid == "closed"
    response = gameservice.post("/game/join", URI.encode_www_form({player_uuid: player_uuid}))
    game_uuid = response.body[:game_uuid]
    puts "Joined game - #{ game_uuid }"
  end
  response = gameservice.post("/game/play", URI.encode_www_form({player_uuid: player_uuid, game_uuid: game_uuid}))
  game_uuid = response.body[:game_uuid]
  number = response.body[:number]
  puts "#{player_uuid}->tick(#{number}) for game # #{game_uuid}"

  sleep 1
end
