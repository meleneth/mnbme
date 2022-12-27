# frozen_string_literal: true

# config.ru
require 'securerandom'
require 'json'
require 'redis'
require 'newrelic_rpm'

app = proc do |env|
  request = Rack::Request.new env
  redis = Redis.new(host: 'gameredis', password: 'gameredis_password')
  uuid = SecureRandom.uuid
  name = request.params['name']
  redis.set("player:name##{uuid}", name)
  redis.set("player:medals##{uuid}", 0)
  [
    200,
    { 'content-type' => 'application/json' },
    [{ name: name, player_uuid: uuid }.to_json]
  ]
end

run app
