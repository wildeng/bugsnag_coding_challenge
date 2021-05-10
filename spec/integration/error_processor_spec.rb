# frozen_string_literal: true

require File.expand_path '../spec_helper.rb', __dir__
require 'byebug'

class ErrorProcessorSpec < Minitest::Test
  include Rack::Test::Methods

  def setup
    path = File.join(File.expand_path('../fixtures', __dir__), 'error1.json')
    @payload = File.read(path)
  end

  def test_stats_no_projectId
    get '/stats'
    assert_equal 404, last_response.status
  end

  def test_get_stats
    get '/stats/1234'
    assert_equal 200, last_response.status
    response = JSON.parse(last_response.body)
    assert_equal set_stats[:invalid], response['invalid']
    assert_equal set_stats[:error], response['error']
    assert_equal set_stats[:info], response['info']
    assert_equal set_stats[:warning], response['warning']
  end

  def test_post_no_data
    post '/collect'
    response = { 'error' => 'payload is not correct' }
    assert_equal 400, last_response.status
    assert_equal response, JSON.parse(last_response.body)
  end

  def test_post_json
    response = { 'message' => 'payload accepted' }
    post '/collect', @payload, 'CONTENT_TYPE' => 'application/json'
    assert last_response.ok?
    assert_equal response, JSON.parse(last_response.body)
  end
end
