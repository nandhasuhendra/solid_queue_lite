namespace :solid_queue_lite do
  namespace :telemetry do
    desc "Backfill a current telemetry snapshot for Solid Queue Lite"
    task backfill: :environment do
      stat = SolidQueueLite::Telemetry.backfill!
      puts "Backfilled telemetry snapshot at #{stat.timestamp}"
    end
  end
end
