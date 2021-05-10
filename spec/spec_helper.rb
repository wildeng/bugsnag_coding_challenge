# frozen_string_literal: true

# /spec/spec_helper.rb

# set up the environment
ENV['RACK_ENV'] = 'test'
require 'minitest/autorun'
require 'mocha/minitest'
require 'rack/test'
require 'mock_redis'

# require the sinatra app
require File.expand_path '../app.rb', __dir__
@mock = MockRedis.new

configure do
  set :default_content_type, 'application/json'
  set :redis, @mock
end

def app
  Sinatra::Application
end

# setting a fix set of stats for testing
def set_stats
  {
    "projectId": '1234',
    "invalid": 2,
    "error": 1,
    "info": 0,
    "warning": 2
  }
end

@mock.set('recap:1234', set_stats.to_json)
