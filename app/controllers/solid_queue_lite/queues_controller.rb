module SolidQueueLite
  class QueuesController < ApplicationController
    def index
      redirect_to processes_path
    end

    def pause
      SolidQueueLite::Processes.pause_queue!(params.fetch(:queue_name))
      redirect_to processes_path, notice: "Paused queue #{params[:queue_name]}"
    end

    def resume
      SolidQueueLite::Processes.resume_queue!(params.fetch(:queue_name))
      redirect_to processes_path, notice: "Resumed queue #{params[:queue_name]}"
    end

    def clear
      SolidQueueLite::Processes.clear_queue!(params.fetch(:queue_name))
      redirect_to processes_path, notice: "Cleared ready jobs from queue #{params[:queue_name]}"
    rescue ::SolidQueue::Execution::UndiscardableError => error
      redirect_to processes_path, alert: error.message
    end
  end
end
