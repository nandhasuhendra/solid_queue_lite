class CreateSolidQueueLiteStats < ActiveRecord::Migration[7.1]
  def change
    create_table :solid_queue_lite_stats do |t|
      t.datetime :timestamp, null: false
      t.string :queue_name, null: false
      t.integer :ready_count, null: false, default: 0
      t.integer :failed_count, null: false, default: 0
      t.integer :scheduled_count, null: false, default: 0
      t.integer :success_count, null: false, default: 0
      t.float :avg_latency
    end

    add_index :solid_queue_lite_stats, :timestamp
    add_index :solid_queue_lite_stats, [ :queue_name, :timestamp ]
  end
end
