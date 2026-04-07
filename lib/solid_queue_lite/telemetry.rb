module SolidQueueLite
  module Telemetry
    SNAPSHOT_QUEUE_NAME = "*"
    SAMPLE_WINDOW = 5.minutes
    RETENTION_PERIOD = 7.days
    RANGE_OPTIONS = {
      "1h" => 1.hour,
      "6h" => 6.hours,
      "24h" => 24.hours
    }.freeze

    module_function

    def sample!(timestamp: Time.current)
      snapshot_time = normalize_timestamp(timestamp)
      stat = SolidQueueLite::Stat.create!(snapshot_attributes(snapshot_time))
      prune!(cutoff: snapshot_time - RETENTION_PERIOD)
      stat
    end

    def backfill!(timestamp: Time.current)
      snapshot_time = normalize_timestamp(timestamp)
      latest = SolidQueueLite::Stat.where(queue_name: SNAPSHOT_QUEUE_NAME).order(timestamp: :desc).first

      if latest && latest.timestamp >= snapshot_time - SAMPLE_WINDOW
        latest.update!(snapshot_attributes(latest.timestamp))
        latest
      else
        sample!(timestamp: snapshot_time)
      end
    end

    def dashboard_data(range_key: "24h")
      selected_range = RANGE_OPTIONS.key?(range_key) ? range_key : "24h"
      window_start = Time.current - RANGE_OPTIONS.fetch(selected_range)
      stats = SolidQueueLite::Stat.where(queue_name: SNAPSHOT_QUEUE_NAME, timestamp: window_start..).order(:timestamp)

      {
        selected_range: selected_range,
        stats: stats,
        latest_stat: stats.last,
        current_ready_count: exact_count(ready_relation),
        current_scheduled_count: exact_count(scheduled_relation),
        current_failed_count: exact_count(current_failed_relation),
        worker_count: ::SolidQueue::Process.where(kind: "Worker").count,
        dispatcher_count: ::SolidQueue::Process.where(kind: "Dispatcher").count,
        stale_process_count: ::SolidQueue::Process.prunable.where(kind: [ "Worker", "Dispatcher" ]).count,
        recurring_tasks: recurring_task_rows,
        chart_payload: {
          labels: stats.map { |stat| stat.timestamp.strftime("%H:%M") },
          ready_counts: stats.map(&:ready_count),
          scheduled_counts: stats.map { |stat| stat.respond_to?(:scheduled_count) ? stat.scheduled_count : 0 },
          success_counts: stats.map { |stat| stat.respond_to?(:success_count) ? stat.success_count : 0 },
          failed_counts: stats.map(&:failed_count),
          avg_latencies: stats.map { |stat| stat.avg_latency&.round(2) || 0.0 }
        }
      }
    end

    def snapshot_attributes(timestamp)
      window_start = timestamp - SAMPLE_WINDOW

      {
        timestamp: timestamp,
        queue_name: SNAPSHOT_QUEUE_NAME,
        ready_count: exact_count(ready_relation),
        scheduled_count: exact_count(scheduled_relation),
        failed_count: recent_failed_relation(window_start).count,
        success_count: successful_job_relation(window_start).count,
        avg_latency: average_latency(recent_claimed_relation(window_start))
      }
    end

    def ready_relation
      SolidQueueLite.apply_tenant_scope(::SolidQueue::ReadyExecution.all)
    end

    def scheduled_relation
      SolidQueueLite.apply_tenant_scope(::SolidQueue::ScheduledExecution.all)
    end

    def recent_failed_relation(window_start)
      SolidQueueLite.apply_tenant_scope(::SolidQueue::FailedExecution.where(created_at: window_start..))
    end

    def current_failed_relation
      SolidQueueLite.apply_tenant_scope(::SolidQueue::FailedExecution.all)
    end

    def successful_job_relation(window_start)
      SolidQueueLite.apply_tenant_scope(
        ::SolidQueue::Job.left_outer_joins(:failed_execution)
          .where(finished_at: window_start..)
          .where(solid_queue_failed_executions: { id: nil })
      )
    end

    def recent_claimed_relation(window_start)
      SolidQueueLite.apply_tenant_scope(
        ::SolidQueue::ClaimedExecution.joins(:job).where(
          ::SolidQueue::ClaimedExecution.table_name => { created_at: window_start.. }
        )
      )
    end

    def average_latency(relation)
      adapter_name = relation.connection.adapter_name.downcase

      expression = case adapter_name
      when /postgres/
        Arel.sql("EXTRACT(EPOCH FROM solid_queue_claimed_executions.created_at - solid_queue_jobs.created_at)")
      when /mysql/, /trilogy/
        Arel.sql("TIMESTAMPDIFF(MICROSECOND, solid_queue_jobs.created_at, solid_queue_claimed_executions.created_at) / 1000000.0")
      when /sqlite/
        Arel.sql("(julianday(solid_queue_claimed_executions.created_at) - julianday(solid_queue_jobs.created_at)) * 86400.0")
      else
        raise NotImplementedError, "Unsupported adapter for telemetry sampling: #{relation.connection.adapter_name}"
      end

      relation.average(expression)&.to_f
    end

    def exact_count(relation)
      relation.except(:select, :order).count
    end

    def recurring_task_rows
      recurring_tasks.map do |task|
        latest_execution = recurring_task_executions_for(task).max_by(&:run_at)
        latest_job = latest_execution&.job

        {
          key: task.key,
          description: task.try(:description).presence || task.key.to_s.humanize,
          queue_name: task.try(:queue_name).presence || "solid_queue_recurring",
          schedule: task.schedule,
          class_name: task.try(:class_name).presence || "SolidQueue::RecurringJob",
          last_run_at: latest_execution&.run_at,
          next_run_at: safe_next_run_at(task),
          last_status: recurring_status_for(latest_job)
        }
      end.sort_by { |task| task[:key].to_s }
    rescue StandardError
      []
    end

    def recurring_tasks
      persisted_tasks = if defined?(::SolidQueue::RecurringTask)
        ::SolidQueue::RecurringTask.static.includes(recurring_executions: :job).to_a
      else
        []
      end

      configured_tasks = begin
        ::SolidQueue::Configuration.new.send(:recurring_tasks)
      rescue StandardError
        []
      end

      (persisted_tasks + configured_tasks).uniq { |task| task.key }
    end

    def recurring_task_executions_for(task)
      if task.respond_to?(:recurring_executions)
        Array(task.recurring_executions)
      else
        []
      end
    end

    def safe_next_run_at(task)
      task.next_time if task.respond_to?(:next_time)
    rescue StandardError
      nil
    end

    def recurring_status_for(job)
      return "Not yet run" unless job

      case job.status.to_s
      when "failed"
        "Failed"
      when "claimed"
        "Running"
      when "ready", "scheduled"
        "Queued"
      else
        job.finished_at.present? ? "Succeeded" : job.status.to_s.humanize
      end
    end

    def normalize_timestamp(timestamp)
      value = timestamp.respond_to?(:in_time_zone) ? timestamp.in_time_zone : Time.zone.parse(timestamp.to_s)
      value || Time.current
    end

    def prune!(cutoff: RETENTION_PERIOD.ago)
      SolidQueueLite::Stat.where(SolidQueueLite::Stat.arel_table[:timestamp].lt(cutoff)).delete_all
    end
  end
end
