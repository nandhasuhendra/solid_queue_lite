require "rails"
require "rails/engine"
require "solid_queue"
require "solid_queue_lite/install"
require "solid_queue_lite/version"

module SolidQueueLite
  class Configuration
    attr_reader :tenant_scope
    attr_accessor :telemetry_backfill_on_boot

    def initialize
      self.tenant_scope = ->(relation) { relation }
      self.telemetry_backfill_on_boot = true
    end

    def tenant_scope=(callable)
      unless callable.respond_to?(:call)
        raise ArgumentError, "tenant_scope must respond to #call"
      end

      @tenant_scope = callable
    end
  end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end
    alias config configuration

    def configure
      yield(configuration)
    end

    def apply_tenant_scope(relation)
      configuration.tenant_scope.call(relation)
    end
  end
end

require "solid_queue_lite/approximate_counter"
require "solid_queue_lite/jobs"
require "solid_queue_lite/processes"
require "solid_queue_lite/telemetry"
require "solid_queue_lite/engine"
