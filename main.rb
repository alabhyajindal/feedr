require 'httparty'
require 'nokogiri'
require 'sinatra'
require 'cgi/util'

# User provided
response = HTTParty.get('https://plurrrr.com/')

html = response.body

doc = Nokogiri::HTML(html)

items = doc.css('article').map do |item|
  first = CGI.escapeHTML(item.css('h2').text)
  second = CGI.escapeHTML(item.css('blockquote p').text)
  third = CGI.escapeHTML(item.css('h2 a').attribute('href').value)

  { first: first, second: second, third: third }
  
end

get '/' do
  content_type 'text/xml'
  erb :index, locals: { items: items }
end