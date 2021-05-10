require 'sinatra'
require 'sinatra/contrib'
require 'json'
require 'redis'
require_relative './services/process_payload.rb'

# stiing up the defaul environment for redis
ENV['RACK_ENV'] ||= 'development'

configure do
  # setting up default content type and
  # a redis connector
  set :default_content_type, 'application/json'
  set :redis, Redis.new
end

# gets the stats for a specific projectId
#
# @param projectId [String] the id of the project
# @return [JSON] returns the project stats or an error
get '/stats/:projectId' do
  return 400 unless params['projectId']
  stats = settings.redis.get("recap:#{params['projectId']}")
  return 404 unless stats
  stats
end

# gets the stats for a specific projectId
#
# @return [JSON] returns an acceptance message or an error
post '/collect' do
  payload = request.body.read
  return 400 if payload.empty?

  # pushing the payload on redis
  settings.redis.lpush "error", payload

  json({'message': 'payload accepted'})
rescue => e
  logger.error "an error occurred: #{ e.message }"
  logger.error "stacktrace: #{ e.backtrace.join('\n') }"
  500
end

# the thread runs until the main Sinatra process is killed
# it pops from the "error" queue the payload and processes it.
# It waits a random interval between 10ms and 1s to simulate
# a database interaction
Thread.new do
  while true do
    begin
      # reading from the redis queue and removing the payload
      data = settings.redis.lpop('error')
      if data
        processor = ProcessPayload.new(data: data, redis_conn: settings.redis)
        processor.process_payload
      end

      # random sleeper between 10ms and 1 s to simulate
      # database interaction
      sleeper = (rand * (1 - 0.010) + 0.001).round(3)
      sleep(sleeper)
    rescue => e
      puts "an error occurred: #{ e.message }"
      puts "stacktrace: #{ e.backtrace.join('\n') }"
    end
  end
end


# defining some errors

error 400 do
  json({'error': 'payload is not correct'})
end

error 404 do
  json({'error': 'cannot find the requested project'})
end

error 500 do
  json({'error': 'an error occurred'})
end
