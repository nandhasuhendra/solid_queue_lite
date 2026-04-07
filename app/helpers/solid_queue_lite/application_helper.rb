module SolidQueueLite
  module ApplicationHelper
    def dashboard_route_params(overrides = {})
      {
        tab: params[:tab].presence || "pulse",
        range: params[:range].presence || "24h",
        queue_name: params[:queue_name].presence,
        state: params[:state].presence || "failed",
        page: params[:page].presence,
        per_page: params[:per_page].presence
      }.merge(overrides).compact
    end

    def dashboard_return_to(overrides = {})
      root_path(dashboard_route_params(overrides))
    end

    def dashboard_relative_time(timestamp)
      return "n/a" unless timestamp
      return "Just now" if timestamp >= 1.minute.ago

      I18n.with_locale(:en) do
        "#{time_ago_in_words(timestamp)} ago"
      end
    end
  end
end
