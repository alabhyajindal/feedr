require 'httparty'
require 'nokogiri'
require 'sinatra'
require 'cgi/util'
require 'json'

# response = HTTParty.get('https://plurrrr.com/')

# html = response.body

# doc = Nokogiri::HTML(html)

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

def extractHTML(url, identifiers)
  # response = HTTParty.get(url)
  # html = response.body
  html = File.read('./test')
  doc = Nokogiri::HTML(html)

  output = identifiers.map do |identifier|
    if identifier[:attribute] == 'text'
      doc.css(identifier[:element]).map { |elem| CGI.escapeHTML(elem.text) }
    else
      doc.css(identifier[:element]).map { |elem| CGI.escapeHTML(elem.attribute(identifier[:attribute]).value) }
    end
  end

  min_length = output.map { |o| o.size }.min

  new_array = (0...min_length).map do |i|
    result = {}

    identifiers.each_with_index do |identifier, index|
      result[:"value#{index + 1}"] = output[index][i]
    end

    result
  end
end

def extraction_guide(identifiers)
  lines = identifiers.split("\n")

  lines.map do |line|
    element, attribute = line.split("=")
    {element: element.strip, attribute: attribute ? attribute.strip : "text"}
  end
end

get '/' do
  erb :index
end

get '/source/' do
  send_file './test'
end

post '/extract' do
  request_body = JSON.parse(request.body.read)
  url, identifiers = request_body.values_at('url', 'identifiers')
  
  identifiers = extraction_guide(identifiers)
  extractions = extractHTML(url, identifiers)

  content_type 'application/json'
  extractions.to_json
end

=begin
  Create UI

  (to get HTML)
  Input to enter URL
  Button to fetch HTML
  Textarea to display HTML

  (to define search pattern)
  Textarea for parent identifier
  Textarea for individual item identifier
  Button to extract 
  Textarea to show extracted content
=end
