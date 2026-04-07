module SolidQueueLite
  class ProcessesController < ApplicationController
    def index
      data = SolidQueueLite::Processes.index_data
      @processes = data[:processes]
      @heartbeat = data[:heartbeat]
      @queues = data[:queues]

      respond_to do |format|
        format.html
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
        format.html { redirect_to processes_path, notice: "Pruned approximately #{prunable_before} stale process record(s)" }
        format.json do
          render json: {
            pruned: true,
            approximate_pruned_count: prunable_before
          }
        end
      end
    end
  end
end
