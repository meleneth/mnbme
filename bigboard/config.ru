# config.ru
require 'faraday'


def get_board
  gameservice = Faraday.new(url: 'http://gameservice:9292') do |f|
    f.response :json, parser_options: { symbolize_names: true }
  end
  response = gameservice.get("/game/list").body
  lines = []
  lines << "<ul>"
  response.each do |k, v|
    lines << "<li><h1>"
    lines << v[:boss_name]
    lines << " #{ v[:number] }/#{v[:maxnumber]}"
    lines << "</h1><ul>"
    v[:players].each do |player|
      lines << "<li>#{ player[:name] } - #{player[:medals]}</li>"
    end
    lines << "</ul></li>"
  end
  lines << "</ul>"
  return "<div><h1>BigBoard</h1><div>#{ lines.join("\n") }</div><p>and status</p></div>"
end

app = Proc.new {
  '/game/list'
  [
    200,
    { "content-type" => "text/html" },
    ["<html><head><meta http-equiv=\"refresh\" content=\"5\"></head><body>#{ get_board }</body></html>"]
  ]
}
run app
