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

def extract_HTML(url, identifiers)
  response = HTTParty.get(url)
  html = response.body
  # html = File.read('./test')
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

post '/load' do
  # for testing
  # html = File.read('./test')

  request_body = JSON.parse(request.body.read)
  url = request_body.values_at('url')[0]

  begin
    response = HTTParty.get(url)
  
    if response.success?
      html = response.body
      "<textarea autocomplete='off' readonly id='html' name='html' cols='70' rows='30'>#{html}</textarea>"
    else
      "<textarea autocomplete='off' readonly id='html' name='html' cols='70' rows='30'>We are unable to download the HTML from your URL. Please try again later.</textarea>"
    end
  
  rescue => e
    "<textarea autocomplete='off' readonly id='html' name='html' cols='70' rows='30'>#{e.message}</textarea>"
  end
  

end

post '/extract' do
  request_body = JSON.parse(request.body.read)
  url, identifiers = request_body.values_at('url', 'identifiers')

  identifiers = extraction_guide(identifiers)
  extractions = extract_HTML(url, identifiers)

  content_type 'application/json'
  extractions.to_json
end

post '/feed/create' do
  request_body = JSON.parse(request.body.read)
  url, identifiers, title, link, description = request_body.values_at('url', 'identifiers', 'title', 'link', 'description')
end

=begin
  Add section to enter feed details (title, link, description)
  Add submit button to complete feed creation

  Write docs for feed creation on /docs

  Set up SQLite database
  Insert row in db on feed creation
=end