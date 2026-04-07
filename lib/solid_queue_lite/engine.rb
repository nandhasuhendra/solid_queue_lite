module SolidQueueLite
  class Engine < ::Rails::Engine
    isolate_namespace SolidQueueLite

    initializer "solid_queue_lite.configuration" do
      SolidQueueLite.configuration
    end

    config.after_initialize do
      next unless SolidQueueLite.configuration.telemetry_backfill_on_boot
      next unless ActiveRecord::Base.connected?
      next unless ActiveRecord::Base.connection.data_source_exists?("solid_queue_lite_stats")

      SolidQueueLite::Stat
      SolidQueueLite::Telemetry.backfill!
    rescue StandardError
      nil
    end
  end
end
