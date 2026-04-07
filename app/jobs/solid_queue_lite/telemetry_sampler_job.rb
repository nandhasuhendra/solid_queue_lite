require "json"

module SolidQueueLite
  class TelemetrySamplerJob < ApplicationJob
    queue_as :default

    def perform(timestamp: Time.current)
      SolidQueueLite::Telemetry.sample!(timestamp: timestamp)
    end
  end
end
