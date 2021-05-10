# frozen_string_literal: true

require 'clockwork'
require 'resque'
require 'active_support/time'
require './app'
require_relative './jobs/payload_processor'
require_relative './services/process_payload'

module Clockwork
  handler do |job|
    Resque.enqueue(job, 'error', Redis.new, ProcessPayload.new)
  end

  every(1.minute, 'Reading from the queue') { PayloadProcessor }
end
