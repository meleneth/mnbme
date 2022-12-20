# config.ru
app = Proc.new {
  [
    200,
    { "content-type" => "text/html" },
    ["Hello, Rack"]
  ]
}
run app
