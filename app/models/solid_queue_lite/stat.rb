module SolidQueueLite
  class Stat < ApplicationRecord
    self.table_name = "solid_queue_lite_stats"

    validates :timestamp, :queue_name, presence: true
  end
end
