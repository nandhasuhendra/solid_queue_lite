module SolidQueueLite
  class JobsController < ApplicationController
    rescue_from ::ActiveRecord::RecordNotFound, with: :render_not_found

    def index
      state_key = requested_state_key
      data = SolidQueueLite::Jobs.list(
        state_key: state_key,
        page: requested_page,
        per_page: requested_per_page,
        queue_name: params[:queue_name],
        include_details: true
      )

      @jobs = data[:jobs]
      @selected_state = data[:selected_state]
      @state_options = data[:state_options]
      @selected_queue_name = data[:selected_queue_name]
      @pagination = data[:pagination]

      respond_to do |format|
        format.json do
          render json: {
            jobs: @jobs,
            pagination: @pagination,
            filters: {
              state: state_key
            }
          }
        end
      end
    end

    def show
      @job = SolidQueueLite::Jobs.find(params[:id])

      respond_to do |format|
        format.json { render json: SolidQueueLite::Jobs.serialize(@job) }
      end
    end

    def bulk_retry
      retried_count = SolidQueueLite::Jobs.bulk_retry!(job_ids: params[:job_ids], state_key: params.fetch(:state, "failed"))

      respond_to do |format|
        format.json { render json: { retried: retried_count } }
      end
    end

    def bulk_discard
      discarded_count = SolidQueueLite::Jobs.bulk_discard!(job_ids: params[:job_ids], state_key: params.fetch(:state, requested_state_key))

      respond_to do |format|
        format.json { render json: { discarded: discarded_count } }
      end
    rescue ::SolidQueue::Execution::UndiscardableError => error
      render_unprocessable_entity(error)
    end

    def retry
      job = SolidQueueLite::Jobs.retry!(params[:id])

      respond_to do |format|
        format.json do
          render json: {
            id: job.id,
            retried: true,
            state: "ready"
          }
        end
      end
    end

    def discard
      job, previous_state = SolidQueueLite::Jobs.discard!(params[:id])

      respond_to do |format|
        format.json do
          render json: {
            id: job.id,
            discarded: true,
            previous_state: previous_state
          }
        end
      end
    rescue ::SolidQueue::Execution::UndiscardableError => error
      render_unprocessable_entity(error)
    end

    private
      def requested_page
        SolidQueueLite::Jobs.normalize_page(params.fetch(:page, 1))
      end

      def requested_per_page
        SolidQueueLite::Jobs.normalize_per_page(params.fetch(:per_page, SolidQueueLite::Jobs::DEFAULT_PER_PAGE))
      end

      def requested_state_key
        params.fetch(:state, "ready")
      end

      def requested_state(state_key = requested_state_key)
        SolidQueueLite::Jobs.resolve_state(state_key)
      end

      def jobs_redirect_params(default_state: "failed")
        SolidQueueLite::Jobs.jobs_redirect_params(params, default_state: default_state)
      end

      def redirect_target(default_state: "failed")
        return params[:return_to] if params[:return_to].to_s.start_with?("/")

        jobs_path(jobs_redirect_params(default_state: default_state))
      end

      def render_not_found
        respond_to do |format|
          format.json { render json: { error: "Not found" }, status: :not_found }
        end
      end

      def render_unprocessable_entity(error)
        respond_to do |format|
          format.json { render json: { error: error.message }, status: :unprocessable_entity }
        end
      end
  end
end
