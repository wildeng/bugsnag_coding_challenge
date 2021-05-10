# frozen_string_literal: true

require 'json'
require 'redis'

# The class process a JSOn payload according to some basic
# rules
class ProcessPayload
  attr_reader :redis_conn, :payload

  def initialize(data: '', redis_conn: Redis.new)
    @payload = JSON.parse(data)
    @redis_conn = redis_conn
  end

  # it process the payload according to the following rules:
  # projectId must be present
  # message must be present
  # stacktrace must be present
  #
  # It also creates a structure recap used to keep track of the stats
  # among different severity errors per projectId
  def process_payload
    return unless @payload.key?('projectId')

    projectId = @payload['projectId']
    queue = "recap:#{projectId}"
    recap = {
      'projectId' => projectId,
      'invalid' => 0,
      'error' => 0,
      'info' => 0,
      'warning' => 0
    }

    recap = JSON.parse(@redis_conn.get(queue)) if @redis_conn.exists?(queue)

    # if the payload is valid it defaults to severity error for the stats
    # unless a different type of severity is declared
    if valid?
      recap['valid_error'] += 1 unless @payload.key?('severity')
      recap[@payload['severity']] += 1
    else
      recap['invalid'] += 1
    end
    @redis_conn.set(queue, recap.to_json)
  end

  # it validates the payload if it does have the mandatory keys
  # projectId key is validated in the caller because we need it
  # to discriminate among different ones
  def valid?
    mandatory_keys = %w[message stacktrace]
    return false unless mandatory_keys.all? { |key| @payload.key?(key) }
    return false if @payload['stacktrace'].empty?

    true
  end
end
