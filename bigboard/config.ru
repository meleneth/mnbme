# frozen_string_literal: true

# config.ru
require 'faraday'
require 'newrelic_rpm'

# Wrap the bits of the HTML build of BigBoard
class BigBoard
  attr_reader :response

  def call(_env)
    @response = gameservice.get('/game/list').body

    [
      200,
      { 'content-type' => 'text/html' },
      [page]
    ]
  end

  private

  def page
    <<~HERE
      <html>
        <head>
          <meta http-equiv="refresh" content="1" />
            <style>#{style}</style>
        </head>
        <body>#{board}</body>
      </html>
    HERE
  end

  def loglines
    lines = []
    lines << '<ul>'
    response[:logs].each do |log|
      lines << "<li>#{log}</li>"
    end
    lines << '</ul>'
    lines.join "\n"
  end

  def gamelines
    lines = ['<ul>']
    response[:games].each do |_k, v|
      lines << "  <li><h1>#{v[:boss_name]} #{v[:number]}/#{v[:maxnumber]}</h1><ul>"
      v[:players].each do |player|
        lines << "    <li>#{player[:name]} - #{player[:medals]}</li>"
      end
      lines << '  </ul></li>'
    end
    lines << '</ul>'
    lines.join "\n"
  end

  def board
    <<~BOARDHERE
      <h1>BigBoard</h1>
      <div>
      <div class="bigboard">
        <div class="bigboard-child">#{loglines} </div>
        <div class="bigboard-child">#{gamelines} </div>
      </div>
      </div>
      <p>and status</p>
    BOARDHERE
  end

  def style
    <<~HERE
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

  def gameservice
    Faraday.new(url: 'http://gameservice:9292') do |f|
      f.response :json, parser_options: { symbolize_names: true }
    end
  end
end

app = Rack::Builder.app do
  run BigBoard.new
end

run app
