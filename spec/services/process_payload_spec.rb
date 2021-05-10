# frozen_string_literal: true

require File.expand_path '../spec_helper.rb', __dir__
require File.expand_path '../../services/process_payload.rb', __dir__
require 'mock_redis'
require 'byebug'

class ProcessPayloadSpec < Minitest::Test
  def setup
    path = File.join(File.expand_path('../fixtures', __dir__), 'error1.json')
    @valid_payload = File.read(path)

    invalid_path = File.join(File.expand_path('../fixtures', __dir__), 'invalid_payload1.json')
    @invalid_payload = File.read(invalid_path)
  end

  def test_payload_validation
    processor = ProcessPayload.new(data: @valid_payload)
    assert_equal true, processor.valid?
  end

  def test_not_validate_wrong_payload
    processor = ProcessPayload.new(data: @invalid_payload)
    assert_equal false, processor.valid?
  end

  def test_valid_payload_processing
    mr = MockRedis.new
    processor = ProcessPayload.new(data: @valid_payload, redis_conn: mr)
    processor.process_payload

    projectId = JSON.parse(@valid_payload)['projectId']
    recap = JSON.parse(mr.get("recap:#{projectId}"))
    assert_equal 1, recap['error']
  end

  def test_invalid_payload_processing
    mr = MockRedis.new
    processor = ProcessPayload.new(data: @invalid_payload, redis_conn: mr)
    assert_equal false, processor.valid?
    processor.process_payload

    projectId = JSON.parse(@invalid_payload)['projectId']
    recap = JSON.parse(mr.get("recap:#{projectId}"))
    assert_equal 1, recap['invalid']
  end
end
