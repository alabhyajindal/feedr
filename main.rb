require 'httparty'
require 'nokogiri'
require 'sinatra'
require 'cgi/util'
require 'json'
require 'sqlite3'

DB = SQLite3::Database.new('feeds.db')
DB.results_as_hash = true

# items = doc.css('article').map do |item|
#   title = CGI.escapeHTML(item.css('h2').text)
#   description = CGI.escapeHTML(item.css('blockquote p').text)
#   link = CGI.escapeHTML(item.css('h2 a').attribute('href').value)

#   { title: title, description: description, link: link }
# end

# get '/test' do
#   content_type 'text/xml'
#   erb :test, locals: { items: items }
# end

$html_response

def extract_HTML(url, identifiers)
  # testing
  # html = File.read('./test')

  # response = HTTParty.get(url)
  # html = response.body
  doc = Nokogiri::HTML($html_response)

  output = identifiers.map do |identifier|
    if identifier[:attribute] == 'text'
      doc.css(identifier[:element]).map { |elem| CGI.escapeHTML(elem.text) }
    else
      doc.css(identifier[:element]).map { |elem| CGI.escapeHTML(elem.attribute(identifier[:attribute]).value) }
    end
  end

  min_length = output.map { |o| o.size }.min

  output_string = (0...min_length).map do |i|
    values = identifiers.map.with_index do |identifier, index|
      if identifier[:attribute] == 'text'
        CGI.escapeHTML(doc.css(identifier[:element])[i].text)
      else
        CGI.escapeHTML(doc.css(identifier[:element])[i].attribute(identifier[:attribute]).value)
      end
    end

    values.join("\n")
  end.join("\n\n")

  return output_string
end


def extraction_guide(identifiers)
  p identifiers
  lines = identifiers.split("\n")

  lines.map do |line|
    element, attribute = line.split("=")
    {element: element.strip, attribute: attribute ? attribute.strip : "text"}
  end
end

get '/' do
  erb :index
end

post '/load' do
  # for testing
  # html = File.read('./test')

  begin
    request_body = JSON.parse(request.body.read)
    url = request_body.values_at('url')[0]
    response = HTTParty.get(url)
  
    if response.success?
      $html_response = response.body
      "<textarea autocomplete='off' readonly id='html' name='html' cols='70' rows='30'>#{$html_response}</textarea>"
    else
      "<textarea autocomplete='off' readonly id='html' name='html' cols='70' rows='30'>We are unable to download the HTML from your URL. Please try again later.</textarea>"
    end
  
  rescue => e
    "<textarea autocomplete='off' readonly id='html' name='html' cols='70' rows='30'>Error: #{e.message}</textarea>"
  end
end

post '/extract' do
  begin
    request_body = JSON.parse(request.body.read)
    url, identifiers = request_body.values_at('url', 'identifiers')

    identifiers = extraction_guide(identifiers)
    extractions = extract_HTML(url, identifiers)

    "<textarea autocomplete='off' readonly id='extractions' name='extractions' cols='70' rows='20'>#{extractions}</textarea>"

  rescue => e
    "<textarea autocomplete='off' readonly id='extractions' name='extractions' cols='70' rows='20'>Error: #{e.message}</textarea>"
  end
end

post '/feed/create' do
  request_body = JSON.parse(request.body.read)
  url, identifiers, title, description = request_body.values_at('url', 'identifiers', 'feed_title', 'feed_description')
  p request_body
  p [url, identifiers, title, description]
  # Save the data to the SQLite database
  DB.execute("INSERT INTO feeds (url, identifiers, title, description) VALUES (?, ?, ?, ?)", [url, identifiers, title, description])

  "Feed saved!"
end

post '/feed/:id/update' do
  feed_id = params['id']
  request_body = JSON.parse(request.body.read)
  url, identifiers, title, description = request_body.values_at('url', 'identifiers', 'feed_title', 'feed_description')

  DB.execute("UPDATE feeds SET url = ?, identifiers = ?, title = ?, description = ? WHERE id = ?", [url, identifiers, title, description, feed_id])

  "Feed updated!"
end

get '/feeds' do
  DB.results_as_hash = true
  feeds = DB.execute('SELECT * FROM feeds;')
  content_type "text/html"
  p feeds
  erb :'feed/index', locals: { feeds: feeds }
end

get '/feed/:id/edit' do
  feed_id = params['id']
  feed = DB.execute('SELECT * FROM feeds WHERE id = ?', feed_id).first

  if feed
    erb :'feed/edit', locals: { feed: feed }
  else
    "Feed not found"
  end
end

get '/feed/new' do
  erb :'feed/new'
end