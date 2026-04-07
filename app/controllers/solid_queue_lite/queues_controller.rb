module SolidQueueLite
  class QueuesController < ApplicationController
    def index
      redirect_to processes_path
    end

    def pause
      SolidQueueLite::Processes.pause_queue!(params.fetch(:queue_name))
      redirect_to redirect_target, notice: "Paused queue #{params[:queue_name]}"
    end

    def resume
      SolidQueueLite::Processes.resume_queue!(params.fetch(:queue_name))
      redirect_to redirect_target, notice: "Resumed queue #{params[:queue_name]}"
    end

    def clear
      SolidQueueLite::Processes.clear_queue!(params.fetch(:queue_name))
      redirect_to redirect_target, notice: "Cleared ready jobs from queue #{params[:queue_name]}"
    rescue ::SolidQueue::Execution::UndiscardableError => error
      redirect_to redirect_target, alert: error.message
    end

    private
      def redirect_target
        return params[:return_to] if params[:return_to].to_s.start_with?("/")

        processes_path
      end
  end
end
