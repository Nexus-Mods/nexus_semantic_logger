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
          datadog_statsd_socket_path = ENV.fetch('DD_STATSD_SOCKET_PATH') { '' }
          datadog_singleton.statsd = if datadog_statsd_socket_path.to_s.strip.empty?
            Datadog::Statsd.new(ENV['DD_AGENT_HOST'], 8125)
          else
            Datadog::Statsd.new(socket_path: datadog_statsd_socket_path)
          end
          c.runtime_metrics.statsd = datadog_singleton.statsd

          # Configure tags to be sent on all traces and metrics.
          # Note that 'env' is NOT sent- that is set as the default on the agent e.g. staging, canary, production.
          # It does not necessarily align with the Rails env, and we do not want to double tag the env.
          datadog_singleton.global_tags = ["railsenv:#{Rails.env}", "service:#{service}"]
          c.tags = datadog_singleton.global_tags

          # Tracer requires configuration to a datadog agent via DD_AGENT_HOST.
          dd_force_tracer_val = ENV.fetch('DD_FORCE_TRACER', false)
          dd_force_tracer = dd_force_tracer_val.present? && dd_force_tracer_val.to_s == 'true'
          dd_tracer_enabled = Rails.env.production? || dd_force_tracer
          c.tracing.enabled = dd_tracer_enabled

          # Profiling is also provided by ddtrace, we synchronise their feature toggles.
          c.profiling.enabled = dd_tracer_enabled

        else
          # If there is no DD_AGENT_HOST then ensure features are disabled.
          c.runtime_metrics.enabled = false
          c.tracing.enabled = false
          c.profiling.enabled = false
        end

        c.tracing.instrument(:rails, service_name: service)

        c.logger.level = Logger::WARN # ddtrace info logging is too verbose.
      end
    end
  end
end
