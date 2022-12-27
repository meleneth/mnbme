# frozen_string_literal: true

# config.ru
require 'newrelic_rpm'

app = proc do
  [
    200,
    { 'content-type' => 'text/html' },
    ['Hello, Rack']
  ]
end
run app
