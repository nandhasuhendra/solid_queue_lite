module SolidQueueLite
  class ProcessesController < ApplicationController
    def index
      data = SolidQueueLite::Processes.index_data
      @processes = data[:processes]
      @heartbeat = data[:heartbeat]
      @queues = data[:queues]

      respond_to do |format|
        format.json do
          render json: {
            processes: @processes,
            heartbeat: @heartbeat
          }
        end
      end
    end

    def prune
      prunable_before = SolidQueueLite::Processes.prune!

      respond_to do |format|
        format.json do
          render json: {
            pruned: true,
            approximate_pruned_count: prunable_before
          }
        end
      end
    end

    private
      def redirect_target
        return params[:return_to] if params[:return_to].to_s.start_with?("/")

        processes_path
      end
  end
end
