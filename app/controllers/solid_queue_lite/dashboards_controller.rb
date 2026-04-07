module SolidQueueLite
  class DashboardsController < ApplicationController
    def show
      data = SolidQueueLite::Telemetry.dashboard_data(range_key: params.fetch(:range, "24h"))

      @selected_range = data[:selected_range]
      @stats = data[:stats]
      @latest_stat = data[:latest_stat]
      @current_ready_count = data[:current_ready_count]
      @current_scheduled_count = data[:current_scheduled_count]
      @current_failed_count = data[:current_failed_count]
      @worker_count = data[:worker_count]
      @dispatcher_count = data[:dispatcher_count]
      @stale_process_count = data[:stale_process_count]
      @chart_payload = data[:chart_payload]
    end
  end
end
