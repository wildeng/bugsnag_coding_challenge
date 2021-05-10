# frozen_string_literal: true

class PayloadProcessor
  @queue = :payload_processor

  def self.perform(reading_queue, redis_connector, processor)
    payload = redis_connector.lpop(reading_queue)
    processor.new(data: payload, redis_conn: redis_connector).process_payload
  end
end
