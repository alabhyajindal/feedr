require 'httparty'
require 'nokogiri'
require 'sinatra'
require 'cgi/util'
require 'json'
require 'sqlite3'

DB = SQLite3::Database.new('feedr.db')
DB.results_as_hash = true

# Helper functions

def extract_html(url, identifiers)
  lines = identifiers.split("\n")

  identifiers = lines.map do |line|
    element, attribute = line.split("=")
    { element: element.strip, attribute: attribute ? attribute.strip : "text" }
  end

  response = HTTParty.get(url)
  doc = Nokogiri::HTML(response.body)

  output = identifiers.map do |identifier|
    if identifier[:attribute] == 'text'
      doc.css(identifier[:element]).map { |elem| CGI.escapeHTML(elem.text) }
    else
      doc.css(identifier[:element]).map { |elem| CGI.escapeHTML(elem.attribute(identifier[:attribute]).value) }
    end
  end

  min_length = output.map { |o| o.size }.min

  (0...min_length).map do |i|
    result = {}

    identifiers.each_with_index do |identifier, index|
      case index
      when 0
        result[:title] = output[index][i].strip
      when 1
        result[:link] = output[index][i].strip
      when 2
        result[:description] = output[index][i].strip
      end
    end

    result
  end
end


def pp_extracted_html(extractions) 
  pp_string = ''
  extractions.map do |e|
    e.values.each.with_index do |value, index|
      pp_string += value + "\n"
      pp_string += "\n\n" if index == e.values.size - 1
    end
  end
  pp_string
end

def generate_xml(url, extractions, feed_title, feed_link, feed_description)
  builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
    xml.rss(version: '2.0') do
      xml.channel do
        xml.title feed_title
        xml.link feed_link
        xml.description feed_description

        extractions.each do |e|
          xml.item do
            e.each do |key, value|
              xml.send(key, value)
            end
          end
        end
      end
    end
  end

  builder.to_xml
end

# extractions = extract_html('https://plurrrr.com/', "article h2\narticle h2 a=href")
# my_xml = generate_xml('https://plurrrr.com/', extractions, 'my title', 'my desc')
# puts my_xml


# Routes
# Feed actions, create, update and delete

def handle_feed(action, request_body, feed_id = nil)
  url, identifiers, feed_title, feed_link, feed_description = request_body.values_at('url', 'identifiers', 'feed_title', 'feed_link', 'feed_description')

  case action
  when 'create'
    DB.execute("INSERT INTO feeds (url, identifiers, feed_title, feed_link, feed_description) VALUES (?, ?, ?, ?, ?)", [url, identifiers, feed_title, feed_link, feed_description])
  when 'update'
    DB.execute("UPDATE feeds SET url = ?, identifiers = ?, feed_title = ?, feed_link = ?, feed_description = ? WHERE id = ?", [url, identifiers, feed_title, feed_link, feed_description, feed_id])
  end

  status 200
  headers 'HX-Redirect' => '/feeds'
end

post '/feed/create' do
  feed_id = params['id']
  request_body = JSON.parse(request.body.read)
  handle_feed('create', request_body)
end

post '/feed/:id/update' do
  feed_id = params['id']
  request_body = JSON.parse(request.body.read)
  handle_feed('update', request_body, feed_id)
end

delete '/feed/:id/delete' do
  feed_id = params['id']

  DB.execute("DELETE FROM feeds WHERE id = ?", feed_id)

  status 200
  headers 'HX-Redirect' => '/feeds'
end

# Feed actions, index, edit and new

get '/feeds' do
  @page_title = "My feeds | Feedr"

  feeds = DB.execute('SELECT * FROM feeds;')
  erb :'feed/index', locals: { feeds: feeds }
end

get '/feed/:id/edit' do
  @page_title = "Edit feed | Feedr"

  feed_id = params['id']
  feed = DB.execute('SELECT * FROM feeds WHERE id = ?', feed_id).first

  if feed
    erb :'feed/edit', locals: { feed: feed }
  else
    "Feed not found"
  end
end

get '/feed/new' do
  @page_title = "Add feed | Feedr"
  erb :'feed/new'
end

get '/feed/:id' do
  feed_id = params['id']
  feed = DB.execute('SELECT * FROM feeds WHERE id = ?', feed_id).first
  if feed
    url, identifiers, feed_title, feed_link, feed_description = feed.values_at('url', 'identifiers', 'feed_title', 'feed_link', 'feed_description')

    extractions = extract_html(url, identifiers)
    xml_data = generate_xml(url, extractions, feed_title, feed_link, feed_description)

    content_type 'application/xml'
    xml_data
  else
    "Feed not found"
  end
end

# Actions

post '/extract' do
  begin
    request_body = JSON.parse(request.body.read)
    url, identifiers = request_body.values_at('url', 'identifiers')

    extractions = extract_html(url, identifiers)
    pp_extractions = pp_extracted_html(extractions)

    "<textarea autocomplete='off' readonly id='extractions' name='extractions' cols='70' rows='20'>#{pp_extractions}</textarea>"

  rescue => e
    "<textarea autocomplete='off' readonly id='extractions' name='extractions' cols='70' rows='20'>Error: #{e.message}</textarea>"
  end
end

# Others

get '/' do
  erb :index
end

get '/guide' do
  @page_title = "Guide | Feedr"
  erb :guide
end