module SolidQueueLite
  module ApproximateCountable
    extend ActiveSupport::Concern

    private
      def approximate_count(relation)
        SolidQueueLite::ApproximateCounter.count(relation)
      end
  end
end
