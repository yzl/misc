#!/usr/bin/env ruby

require 'json'
require 'open-uri'

#
# Set start timestamp, end timestamp, jenkins master
#

# http://www.unixtimestamp.com/index.php
# start timestamp:  midnight August 1 2015 UTC
start_timestamp = 1438387200000 

# end timestamp:  midnight September 1 2015 UTC
end_timestamp = 1441065600000

# name of jenkins master
jenkins_master=''
 
jenkins_url="http://#{jenkins_master}.ci.chef.co/api/json"

def json_result(url)
  JSON.parse(open(url).read)
end

class JenkinsJob
  attr_reader :name, :type, :url, :pipeline

  def initialize(name, type, url, pipeline)
    @name = name
    @type = type
    @url = url
    @pipeline = pipeline
  end
end

class BuildData
  attr_reader :job_url, :start_timestamp, :end_timestamp

  def initialize(job_url, start_timestamp, end_timestamp)
    @job_url = job_url
    @start_timestamp = start_timestamp 
    @end_timestamp = end_timestamp 
  end

  def mean
    durations = build_data.reject { |j| !j['result'].eql?('SUCCESS') }.collect { |j| j['duration'] }
    total = durations.inject { |sum, d| sum + d }
    return total / successes unless successes == 0
    return "No successful build in the specified time period" 
  end

  def numbuilds
    build_data.length    
  end

  def successes
    count('SUCCESS')
  end

  def failures
    count('FAILURE')
  end

  def aborts
    count('ABORTED')
  end

  def unstables
    count('UNSTABLE')
  end

  def get_good
    all_timestamps.select { |t| t['timestamp'].to_i >= start_timestamp && t['timestamp'].to_i <= end_timestamp }.collect { |t| t['number'] }.sort
  end

  def good
    @good ||= get_good
  end

  private

  def all_timestamps
    @all_timestamps ||= get_all_timestamps
  end

  def build_data
    range_url = @job_url +  "api/json?tree=allBuilds[number,duration,result]%7B#{left},#{right}%7D"
    json_result(range_url)['allBuilds']
  end

  def count(thing)
    build_data.find_all { |j| j['result'].eql?(thing) }.length
  end

  def get_all_timestamps
    ts_url = @job_url + '/api/json?tree=allBuilds[number,timestamp]'
    json_result(ts_url)['allBuilds']
  end

  def get_latest_build
    last_build_url = @job_url + 'lastBuild/api/json?tree=number'
    last_build_number = json_result(last_build_url)
    last_build_number['number'].to_i
  end

  def get_left
    latest_build - good[-1]
  end

  def get_right
    left + good.length
  end

  def latest_build
    @latest_build ||= get_latest_build
  end

  def left
    @left ||= get_left
  end

  def right
    @right ||= get_right
  end
end

jobs = []
json_result(jenkins_url)['jobs'].each do |j|
  next if j['name'].include?('trigger')
  %w(build test release).each do |job_type|
    if j['name'].include?(job_type)  
      jobs.push(JenkinsJob.new(j['name'], job_type, j['url'], j['name'].gsub("-#{job_type}",'')))
    end
  end
end

pipeline_names = []
pipeline_results = []
puts "Job Name,Job Type,Pipeline,NumBuilds,Mean Duration of Successful Run(ms),Successes,Failures,Aborts,Unstable"
jobs.each do |job|
  job_stuff = BuildData.new(job.url, start_timestamp, end_timestamp)
  if job_stuff.good.empty?
    puts "#{job.name},No builds during the specified time period"
    next
  end
  puts "#{job.name},#{job.type},#{job.pipeline},#{job_stuff.numbuilds},#{job_stuff.mean},#{job_stuff.successes},#{job_stuff.failures},#{job_stuff.aborts},#{job_stuff.unstables}"
  pipeline_names.push(job.pipeline)
  pipeline_results.push([job.pipeline,job.type,job_stuff.successes,job_stuff.mean])
end

puts "\nPipeline,Mean Successful Run Duration(ms)"

pn = pipeline_names.sort.uniq
pn.each do |name|
  # Take the weighted average of the build/test/release components of the pipeline
  pr = pipeline_results.find_all { |result| result[0].eql?(name) }
  if pr.any? { |result| result[3].eql?('No successful build in the specified time period') }
    puts "#{name},No successful pipeline runs during the specified time period"
    next
  end
  cs = 0
  qu = 0
  denominator = pr.collect { |r| r[2] }.inject { |qu,r| qu + r } 
  if denominator == 0
    puts "#{name},No successful pipeline runs during the specified time period"
    next
  end
  numerator = pr.collect { |r| r[2] * r[3] }.inject { |cs,r| cs +r }
  quotient = numerator / denominator
  puts "#{name},#{quotient}"
end
