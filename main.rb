require 'httparty'
require 'nokogiri'
require 'sinatra'
require 'cgi/util'

# response = HTTParty.get('https://plurrrr.com/')

# html = response.body

# doc = Nokogiri::HTML(html)

# items = doc.css('article').map do |item|
#   title = CGI.escapeHTML(item.css('h2').text)
#   description = CGI.escapeHTML(item.css('blockquote p').text)
#   link = CGI.escapeHTML(item.css('h2 a').attribute('href').value)

#   { title: title, description: description, link: link }
# end


get '/' do
  erb :index
end

# get '/test' do
#   content_type 'text/xml'
#   erb :test, locals: { items: items }
# end

get '/source/' do
  send_file './test'
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
