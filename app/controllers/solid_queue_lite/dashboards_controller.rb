module SolidQueueLite
  class DashboardsController < ApplicationController
    DASHBOARD_TABS = %w[pulse jobs processes recurring].freeze
    DASHBOARD_PER_PAGE = 25

    def show
      telemetry_data = SolidQueueLite::Telemetry.dashboard_data(range_key: params.fetch(:range, "24h"))
      process_data = SolidQueueLite::Processes.index_data

      @active_tab = requested_tab
      @selected_range = telemetry_data[:selected_range]
      @stats = telemetry_data[:stats]
      @latest_stat = telemetry_data[:latest_stat]
      @current_ready_count = telemetry_data[:current_ready_count]
      @current_scheduled_count = telemetry_data[:current_scheduled_count]
      @current_failed_count = telemetry_data[:current_failed_count]
      @worker_count = telemetry_data[:worker_count]
      @dispatcher_count = telemetry_data[:dispatcher_count]
      @stale_process_count = telemetry_data[:stale_process_count]
      @recurring_tasks = telemetry_data[:recurring_tasks]
      @chart_payload = telemetry_data[:chart_payload]

      @processes = process_data[:processes]
      @heartbeat = process_data[:heartbeat]
      @queues = process_data[:queues]

      @selected_queue_name = params[:queue_name].presence
      @selected_queue_metrics = @queues.find { |queue| queue[:name] == @selected_queue_name }
      @jobs_selected_state = params.fetch(:state, "failed")
      @jobs_per_page = SolidQueueLite::Jobs.normalize_per_page(params.fetch(:per_page, DASHBOARD_PER_PAGE))
      @jobs_page = SolidQueueLite::Jobs.normalize_page(params.fetch(:page, 1))

      if @selected_queue_name.present?
        jobs_data = SolidQueueLite::Jobs.list(
          state_key: @jobs_selected_state,
          page: @jobs_page,
          per_page: @jobs_per_page,
          queue_name: @selected_queue_name,
          include_details: true
        )

        @jobs = jobs_data[:jobs]
        @jobs_pagination = jobs_data[:pagination]
      else
        @jobs = []
        @jobs_pagination = {
          page: @jobs_page,
          per_page: @jobs_per_page,
          total_pages: 1,
          approximate_total_count: 0
        }
      end
    end

    private
      def requested_tab
        requested_value = params[:tab].presence || "pulse"
        DASHBOARD_TABS.include?(requested_value) ? requested_value : "pulse"
      end
  end
end
