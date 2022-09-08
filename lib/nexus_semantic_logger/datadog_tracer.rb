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
          c.runtime_metrics.statsd = datadog_singleton.statsd

          # Configure tags to be sent on all traces and metrics.
          # Note that 'env' is NOT sent- that is set as the default on the agent e.g. staging, canary, production.
          # It does not necessarily align with the Rails env, and we do not want to double tag the env.
          datadog_singleton.tags = ["railsenv:#{Rails.env}", "service:#{service}"]
          c.tags = datadog_singleton.tags

          # Tracer requires configuration to a datadog agent via DD_AGENT_HOST.
          dd_force_tracer_val = ENV.fetch('DD_FORCE_TRACER', false)
          dd_force_tracer = dd_force_tracer_val.present? && dd_force_tracer_val.to_s == 'true'
          c.tracer(enabled: Rails.env.production? || dd_force_tracer)
        end

        c.use(:rails, service_name: service)

        c.logger.level = Logger::WARN # ddtrace info logging is too verbose.
      end
    end
  end
end
