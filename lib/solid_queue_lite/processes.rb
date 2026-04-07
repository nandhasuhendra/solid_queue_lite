module SolidQueueLite
  module Processes
    WILDCARD_QUEUE_NAME = "*"

    module_function

    def index_data
      stale_cutoff = ::SolidQueue.process_alive_threshold.ago
      dead_cutoff = (::SolidQueue.process_alive_threshold * 2).ago
      available_queue_names = queue_names
      processes = ::SolidQueue::Process
        .order(:kind, last_heartbeat_at: :desc)
        .pluck(:id, :kind, :name, :pid, :hostname, :last_heartbeat_at, :supervisor_id, :metadata)
        .map do |id, kind, name, pid, hostname, last_heartbeat_at, supervisor_id, metadata|
          status = process_status(last_heartbeat_at, stale_cutoff: stale_cutoff, dead_cutoff: dead_cutoff)

          {
            id: id,
            kind: kind,
            name: name,
            pid: pid,
            hostname: hostname,
            last_heartbeat_at: last_heartbeat_at,
            supervisor_id: supervisor_id,
            stale: status != "active",
            status: status,
            metadata: metadata || {},
            queue_names: queue_names_from_metadata(metadata, fallback_queue_names: available_queue_names)
          }
        end

      {
        processes: processes,
        heartbeat: {
          stale_after_seconds: ::SolidQueue.process_alive_threshold,
          stale_cutoff: stale_cutoff,
          dead_cutoff: dead_cutoff
        },
        queues: queue_rows(queue_names: available_queue_names)
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

    def queue_rows(queue_names: self.queue_names)
      queue_names.map do |queue_name|
        queue_record = queue(queue_name)

        {
          name: queue_name,
          paused: queue_record.paused?,
          ready_estimate: exact_queue_count(queue_name, :ready),
          in_progress_count: exact_queue_count(queue_name, :claimed),
          failed_count: exact_queue_count(queue_name, :failed),
          scheduled_count: exact_queue_count(queue_name, :scheduled),
          recurring_count: exact_queue_count(queue_name, :recurring),
          total_jobs_count: exact_total_jobs_count(queue_name),
          latency_seconds: queue_record.latency,
          human_latency: queue_record.human_latency
        }
      end
    end

    def queue(queue_name)
      ::SolidQueue::Queue.find_by_name(queue_name)
    end

    def exact_queue_count(queue_name, state)
      relation = SolidQueueLite::Jobs.filtered_jobs_relation(state: state, queue_name: queue_name)
      relation.except(:select, :order).count
    end

    def exact_total_jobs_count(queue_name)
      SolidQueueLite::Jobs.scoped_jobs(::SolidQueue::Job.where(queue_name: queue_name)).count
    end

    def process_status(last_heartbeat_at, stale_cutoff:, dead_cutoff:)
      return "dead" unless last_heartbeat_at
      return "dead" if last_heartbeat_at <= dead_cutoff
      return "stale" if last_heartbeat_at <= stale_cutoff

      "active"
    end

    def queue_names_from_metadata(metadata, fallback_queue_names: [])
      return [] unless metadata.is_a?(Hash)

      value = metadata["queues"] || metadata[:queues] || metadata["queue_names"] || metadata[:queue_names]
      queue_names = extract_queue_names(value)

      if queue_names.include?(WILDCARD_QUEUE_NAME)
        (queue_names - [ WILDCARD_QUEUE_NAME ] + fallback_queue_names).uniq
      else
        queue_names
      end
    end

    def queue_names
      (
        ::SolidQueue::Queue.all.map(&:name) +
        configured_queue_names +
        configured_process_queue_names
      ).reject { |queue_name| wildcard_queue_name?(queue_name) }.uniq.sort
    end

    def configured_queue_names
      ::SolidQueue::Configuration.new.configured_processes.filter_map do |configured_process|
        next unless configured_process.kind.to_sym == :worker

        configured_process.attributes[:queues]
      end.flat_map { |value| extract_queue_names(value) }
    rescue StandardError
      []
    end

    def configured_process_queue_names
      ::SolidQueue::Process.pluck(:metadata).flat_map do |metadata|
        next [] unless metadata.is_a?(Hash)

        value = metadata["queues"] || metadata[:queues] || metadata["queue_names"] || metadata[:queue_names]
        extract_queue_names(value)
      end
    end

    def extract_queue_names(value)
      case value
      when String
        value.split(/[\s,]+/).map(&:presence).compact
      when Array
        value.flat_map { |entry| extract_queue_names(entry) }
      else
        []
      end
    end

    def wildcard_queue_name?(queue_name)
      queue_name == WILDCARD_QUEUE_NAME
    end
  end
end
