# frozen_string_literal: true
require 'datadog/statsd'
require 'ddtrace'

module NexusSemanticLogger
  class DatadogTracer
    def initialize(service)
      Datadog.configure do |c|
        if ENV['DD_AGENT_HOST'].present?
          # To enable runtime metrics collection, set `true`. Defaults to `false`
          # You can also set DD_RUNTIME_METRICS_ENABLED=true to configure this.
          c.runtime_metrics.enabled = true

          # Configure DogStatsD instance for sending runtime metrics.
          # By default, runtime metrics from the application are sent to the Datadog Agent with DogStatsD on port 8125.
          datadog_singleton = DatadogSingleton.instance
          datadog_singleton.statsd = Datadog::Statsd.new(ENV['DD_AGENT_HOST'], 8125)
          datadog_singleton.tags = ["env:#{Rails.env}", "service:#{service}"]
          c.runtime_metrics.statsd = datadog_singleton.statsd

          # Tracer requires configuration to a datadog agent via DD_AGENT_HOST.
          dd_force_tracer_val = ENV.fetch('DD_FORCE_TRACER', false)
          dd_force_tracer = dd_force_tracer_val.present? && dd_force_tracer_val.to_s == 'true'
          c.tracer(enabled: Rails.env.production? || dd_force_tracer, env: Rails.env)
        end

        c.use(:rails, service_name: service)

        c.logger.level = Logger::WARN # ddtrace info logging is too verbose.
      end
    end
  end
end
