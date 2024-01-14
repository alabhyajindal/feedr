require 'dotenv'
require 'httparty'
require 'nokogiri'
require 'sinatra'
require 'cgi/util'
require 'json'
require 'sqlite3'
require 'jwt'
require 'resend'

# Config and secrets
Dotenv.load

DB = SQLite3::Database.new('feedr.db')
DB.results_as_hash = true

hmac_secret = ENV['FEEDR_HMAC_SECRET']
Resend.api_key = ENV['FEEDR_RESEND_API_KEY']

enable :sessions
set :session_secret, ENV['FEEDR_SESSION_SECRET']

# XML functions
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


def handle_feed(action, request_body, feed_id = nil)
  url, identifiers, feed_title, feed_link, feed_description = request_body.values_at('url', 'identifiers', 'feed_title', 'feed_link', 'feed_description')
  feed_link[feed_link.size - 1] = "" if feed_link[feed_link.size - 1] == "/"
  user_id = current_user['id']
  
  case action
  when 'create'
    DB.execute("INSERT INTO feeds (url, identifiers, feed_title, feed_link, feed_description, user_id) VALUES (?, ?, ?, ?, ?, ?)", [url, identifiers, feed_title, feed_link, feed_description, user_id])
  when 'update'
    DB.execute("UPDATE feeds SET url = ?, identifiers = ?, feed_title = ?, feed_link = ?, feed_description = ?, user_id = ? WHERE id = ?", [url, identifiers, feed_title, feed_link, feed_description, user_id, feed_id])
  end

  status 200
  headers 'HX-Redirect' => '/feeds'
end

# GET feeds

get '/feeds' do
  authenticate!
  @page_title = "My feeds | Feedr"

  feeds = DB.execute('SELECT * FROM feeds WHERE user_id = ?', current_user['id'])
  erb :'feed/index', locals: { feeds: feeds }
end

get '/feed/:id/edit' do
  authenticate!
  @page_title = "Edit feed | Feedr"

  feed_id = params['id']
  feed = DB.execute('SELECT * FROM feeds WHERE id = ? AND user_id = ?', [feed_id, current_user['id']]).first

  if feed
    erb :'feed/_form', locals: { feed: feed }
  else
    "Feed not found"
  end
end

get '/feed/new' do
  authenticate!
  @page_title = "Add feed | Feedr"
  erb :'feed/_form', locals: { feed: nil }
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

# Post (feeds)

post '/feed/create' do
  authenticate!
  feed_id = params['id']
  request_body = JSON.parse(request.body.read)
  handle_feed('create', request_body)
end

post '/feed/:id/update' do
  authenticate!
  feed_id = params['id']
  request_body = JSON.parse(request.body.read)
  handle_feed('update', request_body, feed_id)
end

# Delete (feeds)

delete '/feed/:id/delete' do
  authenticate!
  feed_id = params['id']
  DB.execute("DELETE FROM feeds WHERE id = ?", feed_id)

  status 200
  headers 'HX-Redirect' => '/feeds'
end

post '/extract' do
  authenticate!
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


# Get (pages)

get '/' do
  erb :index
end

get '/guide' do
  @page_title = "Guide | Feedr"
  erb :guide
end

# Get (user management)

get '/login' do
  redirect '/' if current_user
  @page_title = 'Login | Feedr'
  erb :login
end

get '/login/:token' do
  token = params[:token]
  decoded_token = JWT.decode(token, hmac_secret, true, { algorithm: 'HS256' })
  email, name = decoded_token[0].values_at('email', 'name')

  user = DB.execute("SELECT id FROM Users WHERE email = ?", [email]).first

  if user.nil?
    DB.execute("INSERT INTO Users (email, name) VALUES (?, ?)", [email, name])
    user_id = DB.last_insert_row_id
  else
    user_id = user['id']
  end

  session['user_id'] = user_id
  redirect '/feeds'
end

# Post (user management)

post '/login' do
  request_body = JSON.parse(request.body.read)
  email, name = request_body.values_at('email', 'name')

  payload = { email: email, name: name }
  token = JWT.encode payload, hmac_secret, 'HS256'

  login_link = "#{ENV['BASE_URL']}/login/#{token}"

  params = {
    from: 'Feedr <feedr@auratice.com>',
    to: [email],
    subject: 'Login to Feedr',
    html: "<p>Click on the following link to login to Feedr:</p>
    <p><a href='#{login_link}'>Login</a></p>",
  }

  if ENV['APP_ENV'] == 'production'
    Resend::Emails.send(params).to_hash.to_json
  else
    puts login_link
  end

  "<p><em>Check your email for the login link</em></p>"
end

# Delete (user management)

delete '/logout' do
  session['user_id'] = nil
  status 200
  headers 'HX-Redirect' => '/'
end

def authenticate!
  user_id = session['user_id']
  redirect '/' unless user_id
end

helpers do
  def is_active_link(link_path)
    'active-link' if request.path == link_path
  end

  def escape_html(string)
    CGI.escapeHTML(string)
  end

  def current_user
    user_id = session['user_id']
    if user_id
      @current_user ||= DB.execute("SELECT id, email, name FROM Users WHERE id = ?", [user_id]).first
    end
  end
end