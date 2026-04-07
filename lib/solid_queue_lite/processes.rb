module SolidQueueLite
  module Processes
    module_function

    def index_data
      cutoff = ::SolidQueue.process_alive_threshold.ago
      processes = ::SolidQueue::Process
        .order(:kind, last_heartbeat_at: :desc)
        .pluck(:id, :kind, :name, :pid, :hostname, :last_heartbeat_at, :supervisor_id, :metadata)
        .map do |id, kind, name, pid, hostname, last_heartbeat_at, supervisor_id, metadata|
          {
            id: id,
            kind: kind,
            name: name,
            pid: pid,
            hostname: hostname,
            last_heartbeat_at: last_heartbeat_at,
            supervisor_id: supervisor_id,
            stale: last_heartbeat_at <= cutoff,
            metadata: metadata || {}
          }
        end

      {
        processes: processes,
        heartbeat: {
          stale_after_seconds: ::SolidQueue.process_alive_threshold,
          stale_cutoff: cutoff
        },
        queues: queue_rows
      }
    end

    def prune!
      prunable_before = ::SolidQueue::Process.prunable.where(kind: [ "Worker", "Dispatcher", "Supervisor", "Supervisor(fork)", "Scheduler" ]).count
      ::SolidQueue::Process.prune
      prunable_before
    end

    def pause_queue!(queue_name)
      queue(queue_name).pause
    end

    def resume_queue!(queue_name)
      queue(queue_name).resume
    end

    def clear_queue!(queue_name)
      queue(queue_name).clear
    end

    def queue_rows
      ::SolidQueue::Queue.all.sort_by(&:name).map do |queue_record|
        {
          name: queue_record.name,
          paused: queue_record.paused?,
          ready_estimate: SolidQueueLite::ApproximateCounter.count(::SolidQueue::ReadyExecution.queued_as(queue_record.name)),
          latency_seconds: queue_record.latency,
          human_latency: queue_record.human_latency
        }
      end
    end

    def queue(queue_name)
      ::SolidQueue::Queue.find_by_name(queue_name)
    end
  end
end
