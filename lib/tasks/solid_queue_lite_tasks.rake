namespace :solid_queue_lite do
  desc "Install Solid Queue Lite into the host Rails application"
  task install: :environment do
    SolidQueueLite::Install.new.run!(migrate: ENV["MIGRATE"] == "1")
  end

  namespace :telemetry do
    desc "Backfill a current telemetry snapshot for Solid Queue Lite"
    task backfill: :environment do
      stat = SolidQueueLite::Telemetry.backfill!
      puts "Backfilled telemetry snapshot at #{stat.timestamp}"
    end
  end
end
