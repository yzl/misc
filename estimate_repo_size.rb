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

  size_by_os = Hash.new
  %w[ el ubuntu debian ].each do |os|
    total = 0
    total = results['results'].find_all { |result| result["path"].include?("\/#{os}\/") }
            .inject(0) { |sum, result| sum + Integer(result['size']) } 
    size_by_os[os] = total
  end

  puts "#{channel} yum repo size (bytes) = #{size_by_os['el']}"
  puts "#{channel} apt repo size (bytes) = #{size_by_os['debian'] + size_by_os['ubuntu']}"
end 
