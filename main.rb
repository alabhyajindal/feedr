require 'httparty'
require 'nokogiri'
# require 'sinatra'
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
      {elem: doc.css(identifier[:element]), attr: identifier[:attribute]}
  end

  output = output.map do |o|
    if o[:attr] == 'text'
      o[:elem].text
    else
      o[:elem].attribute(o[:attr]).value
    end
  end

  output.each do |o| 
    puts o
    puts "\n"
  end

end

def extraction_guide(identifiers)
  lines = identifiers.split("\n")

  lines.map do |line|
    element, attribute = line.split("=")
    {element: element.strip, attribute: attribute ? attribute.strip : "text"}
  end
end

guide = extraction_guide("article h2
article blockquote p
article h2 a = href")

extractHTML('https://plurrrr.com/', guide)



# get '/' do
#   erb :index
# end

# get '/source/' do
#   send_file './test'
# end

# post '/extract' do
#   request_body = JSON.parse(request.body.read)
#   url, parent, identifiers = request_body.values_at('url', 'parent', 'identifiers')
#   identifiers = identifiers.split("\n")
#   # p [url, parent, identifiers]
#   extractions = extractHTML(url, parent, identifiers)
#   "foo"
# end

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
