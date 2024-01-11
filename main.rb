require 'httparty'
require 'nokogiri'
require 'sinatra'

# User provided
response = HTTParty.get('https://plurrrr.com/')

html = response.body

doc = Nokogiri::HTML(html)

# items = doc.css('article').map do |item|
#   one = item.css('h2').text
#   two = item.css('blockquote p').text
#   three = item.css('h2 a').attribute('href').value

#   { 1 => one, 2 => two, 3 => three }
# end

# items.each do |item| 
#   puts "\n"
#   puts item[1]
#   puts item[2]
#   puts item[3]
# end

# User provided
one = doc.css('article h2')[0].text
two = doc.css('article blockquote p')[0].text
three = doc.css('article h2 a')[0].attribute('href').value

# puts one
# puts two
# puts three

feedXML = "<?xml version='1.0' encoding='UTF-8' ?>
<rss version='2.0'>

<channel>
  <title>#{one}</title>
  <link>#{three}</link>
  <description>#{two}</description>
</channel>

</rss>"

get '/' do
  content_type 'text/xml'
  feedXML
end