# config.ru
require 'newrelic_rpm'

app = Proc.new {
  [
    200,
    { "content-type" => "text/html" },
    ["Hello, Rack"]
  ]
}
run app
