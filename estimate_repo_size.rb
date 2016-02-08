require 'artifactory'

Artifactory.configure do |config|
  config.endpoint = 'http://artifactory-preprod.chef.co' 
  config.username = 'yvonne@chef.io' 
  config.password = ENV['ARTIFACTORY_PASSWORD'] 
end

%w[ current stable ].each do |channel|

  query = <<-QUERY
items.find(
{ "repo": "omnibus-#{channel}-local" }
).include("path", "name", "size")
QUERY

  results = Artifactory.post('/api/search/aql', query, 'Content-Type' => 'text/plain')

  packages = Hash.new
  size = Hash.new
  %w[ el ubuntu debian ].each do |os|
    total = 0
    stuff = results['results'].find_all { |result| result["path"].include?("\/#{os}\/") }
    packages[os] = stuff.size
    size[os] = stuff.inject(0) { |sum, result| sum + Integer(result['size']) } 
  end

  puts "#{channel} yum repo size (bytes) = #{size['el']} (#{packages['el']} packages)"
  puts "#{channel} apt repo size (bytes) = #{size['debian'] + size['ubuntu']} (#{packages['debian'] + packages['ubuntu']} packages)"
end 
