require 'httparty'
require 'nokogiri'
require 'sinatra'
require 'cgi/util'

response = HTTParty.get('https://plurrrr.com/')

html = response.body

doc = Nokogiri::HTML(html)

items = doc.css('article').map do |item|
  title = CGI.escapeHTML(item.css('h2').text)
  description = CGI.escapeHTML(item.css('blockquote p').text)
  link = CGI.escapeHTML(item.css('h2 a').attribute('href').value)

  { title: title, description: description, link: link }
end

# titles = doc.css('article h2')
# links = doc.css('article blockquote p')
# descriptions = doc.css('article h2 a')

get '/' do
  content_type 'text/xml'
  erb :index, locals: { items: items }
end