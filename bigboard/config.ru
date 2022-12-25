# config.ru
require 'faraday'
require 'newrelic_rpm'


def get_board
  gameservice = Faraday.new(url: 'http://gameservice:9292') do |f|
    f.response :json, parser_options: { symbolize_names: true }
  end
  response = gameservice.get("/game/list").body
  loglines = []
  loglines << "<ul>"
  response[:logs].each do |log|
    loglines << "<li>#{log}</li>"
  end
  loglines << "</ul>"

  lines = []
  lines << "<ul>"
  games = response[:games]
  games.each do |k, v|
    lines << "  <li><h1>#{ v[:boss_name]} #{ v[:number] }/#{v[:maxnumber]}</h1><ul>"
    v[:players].each do |player|
      lines << "    <li>#{ player[:name] } - #{player[:medals]}</li>"
    end
    lines << "  </ul></li>"
  end
  lines << "</ul>"

  return <<BOARDHERE
<h1>BigBoard</h1>
<div>
<div class="bigboard">
  <div class="bigboard-child">#{loglines.join("\n")} </div>
  <div class="bigboard-child">#{lines.join("\n")} </div>
</div>
</div>
<p>and status</p>
BOARDHERE
end

def bigboard_style
  <<HERE
.bigboard {
  display: flex;
}
.bigboard-child {
  flex: 1;
  border: 2px solid yellow;
}
.bigboard-child:first-child {
  margin-right: 20px;
}
HERE
end

app = Proc.new {
  '/game/list'
  [
    200,
    { "content-type" => "text/html" },
    ["<html><head><meta http-equiv=\"refresh\" content=\"5\"><style>#{bigboard_style}</style></head><body>#{ get_board }</body></html>"]
  ]
}
run app
