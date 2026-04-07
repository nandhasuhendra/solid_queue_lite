module SolidQueueLite
  module Jobs
    MAX_PAGES = 10
    DEFAULT_PER_PAGE = 50
    MAX_PER_PAGE = 100
    SUPPORTED_STATES = {
      "ready" => :ready,
      "in_progress" => :claimed,
      "claimed" => :claimed,
      "scheduled" => :scheduled,
      "failed" => :failed,
      "recurring" => :recurring
    }.freeze

    module_function

    def list(state_key:, page: 1, per_page: DEFAULT_PER_PAGE, queue_name: nil)
      state = resolve_state(state_key)
      relation = filtered_jobs_relation(state: state, queue_name: queue_name)
      approximate_total = SolidQueueLite::ApproximateCounter.count(relation)
      total_pages = estimated_total_pages(approximate_total, per_page)

      jobs = relation
        .reorder(created_at: :desc, id: :desc)
        .limit(per_page)
        .offset((page - 1) * per_page)
        .pluck(:id, :class_name, :queue_name)
        .map do |id, class_name, queue_name_value|
          { id: id, class_name: class_name, queue_name: queue_name_value, state: state.to_s }
        end

      {
        jobs: jobs,
        selected_state: state_key,
        selected_queue_name: queue_name.presence,
        state_options: SUPPORTED_STATES.keys,
        pagination: {
          page: page,
          per_page: per_page,
          total_pages: total_pages,
          approximate_total_count: approximate_total,
          max_pages: MAX_PAGES
        }
      }
    end

    def find(id)
      scoped_jobs(
        ::SolidQueue::Job.includes(
          :ready_execution,
          :claimed_execution,
          :failed_execution,
          :scheduled_execution,
          :blocked_execution,
          :recurring_execution
        )
      ).find(id)
    end

    def retry!(id)
      job = scoped_jobs(::SolidQueue::Job.includes(:failed_execution)).find(id)
      raise StandardError, "Only failed jobs can be retried" unless job.failed_execution

      job.failed_execution.retry
      job
    end

    def discard!(id)
      job = find(id)
      previous_state = job.status
      job.discard
      [ job, previous_state ]
    end

    def bulk_retry!(job_ids:, state_key: "failed")
      raise StandardError, "Bulk retry is only available for failed jobs" unless resolve_state(state_key) == :failed

      jobs = selected_jobs(job_ids)
      ::SolidQueue::FailedExecution.retry_all(jobs)
      jobs.size
    end

    def bulk_discard!(job_ids:, state_key:)
      jobs = selected_jobs(job_ids)
      bulk_discard_execution_class(state_key).discard_all_from_jobs(jobs)
      jobs.size
    end

    def serialize(job)
      {
        id: job.id,
        active_job_id: job.active_job_id,
        class_name: job.class_name,
        queue_name: job.queue_name,
        priority: job.priority,
        scheduled_at: job.scheduled_at,
        finished_at: job.finished_at,
        created_at: job.created_at,
        updated_at: job.updated_at,
        concurrency_key: job.concurrency_key,
        arguments: job.arguments,
        state: job.status,
        failed_execution: serialize_failed_execution(job.failed_execution),
        recurring_execution: serialize_recurring_execution(job.recurring_execution)
      }
    end

    def resolve_state(state_key)
      SUPPORTED_STATES.fetch(state_key)
    rescue KeyError
      raise ::ActionController::BadRequest, "state must be one of: #{SUPPORTED_STATES.keys.join(', ')}"
    end

    def normalize_page(page)
      value = page.to_i
      raise ::ActionController::BadRequest, "page must be between 1 and #{MAX_PAGES}" if value < 1 || value > MAX_PAGES

      value
    end

    def normalize_per_page(per_page)
      value = per_page.to_i
      return DEFAULT_PER_PAGE if value <= 0

      [ value, MAX_PER_PAGE ].min
    end

    def selected_jobs(job_ids)
      ids = Array(job_ids).map(&:to_i).uniq
      raise ::ActionController::BadRequest, "At least one job must be selected" if ids.empty?

      jobs = scoped_jobs(::SolidQueue::Job.where(id: ids)).to_a
      raise ::ActionController::BadRequest, "Selected jobs could not be found" if jobs.empty?

      jobs
    end

    def jobs_redirect_params(params, default_state: "failed")
      {
        state: params[:state].presence || default_state,
        queue_name: params[:queue_name].presence,
        per_page: params[:per_page].presence,
        page: params[:page].presence
      }.compact
    end

    def scoped_jobs(relation = ::SolidQueue::Job.all)
      SolidQueueLite.apply_tenant_scope(relation)
    end

    def filtered_jobs_relation(state:, queue_name: nil)
      relation = scoped_jobs(::SolidQueue::Job.all)
      relation = relation.where(queue_name: queue_name) if queue_name.present?

      case state
      when :ready
        relation.joins(:ready_execution)
      when :claimed
        relation.joins(:claimed_execution)
      when :scheduled
        relation.joins(:scheduled_execution)
      when :failed
        relation.joins(:failed_execution)
      when :recurring
        relation.joins(:recurring_execution)
      else
        raise ::ActionController::BadRequest, "Unsupported state filter: #{state}"
      end
    end

    def serialize_failed_execution(failed_execution)
      return unless failed_execution

      {
        id: failed_execution.id,
        message: failed_execution.message,
        exception_class: failed_execution.exception_class,
        backtrace: failed_execution.backtrace,
        created_at: failed_execution.created_at
      }
    end

    def serialize_recurring_execution(recurring_execution)
      return unless recurring_execution

      {
        id: recurring_execution.id,
        task_key: recurring_execution.task_key,
        run_at: recurring_execution.run_at,
        created_at: recurring_execution.created_at
      }
    end

    def estimated_total_pages(approximate_total, per_page)
      pages = (approximate_total.to_f / per_page).ceil
      pages = 1 if pages.zero?
      [ pages, MAX_PAGES ].min
    end

    def bulk_discard_execution_class(state_key)
      case resolve_state(state_key)
      when :ready
        ::SolidQueue::ReadyExecution
      when :scheduled
        ::SolidQueue::ScheduledExecution
      when :failed
        ::SolidQueue::FailedExecution
      else
        raise ::ActionController::BadRequest, "Bulk discard is supported only for ready, scheduled, and failed jobs"
      end
    end
  end
end
