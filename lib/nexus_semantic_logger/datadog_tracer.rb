# frozen_string_literal: true
require 'datadog/statsd'
require 'ddtrace'

module NexusSemanticLogger
  class DatadogTracer
    def initialize(service)
      Datadog.configure do |c|
        if ENV['DD_AGENT_HOST'].present?

          # Container and pod names should be set as env vars via the helm chart. Tagging metrics from the app
          # with these values helps correlation with metrics from the kubernetes cluster.
          container_name = ENV.fetch('CONTAINER_NAME') { '' }
          pod_name = ENV.fetch('POD_NAME') { '' }

          # Configure tags to be sent on all metrics.
          # Note that 'env' is NOT sent- that is set as the default on the agent e.g. staging, canary, production.
          # It does not necessarily align with the Rails env, and we do not want to double tag the env.
          global_tags = [
            "railsenv:#{Rails.env}",
            "service:#{service}",
            "container_name:#{container_name}",
            "pod_name:#{pod_name}",
          ]

          # To enable runtime metrics collection, set `true`. Defaults to `false`
          # You can also set DD_RUNTIME_METRICS_ENABLED=true to configure this.
          c.runtime_metrics.enabled = true

          # Configure DogStatsD instance for sending runtime metrics.
          # By default, runtime metrics from the application are sent to the Datadog Agent with DogStatsD on port 8125.
          datadog_singleton = DatadogSingleton.instance
          datadog_statsd_socket_path = ENV.fetch('DD_STATSD_SOCKET_PATH') { '' }
          datadog_singleton.statsd = if datadog_statsd_socket_path.to_s.strip.empty?
            Datadog::Statsd.new(ENV['DD_AGENT_HOST'], 8125, tags: global_tags)
          else
            Datadog::Statsd.new(socket_path: datadog_statsd_socket_path, tags: global_tags)
          end
          c.runtime_metrics.statsd = datadog_singleton.statsd

          # Trace tags API is Hash<String,String>, see https://www.rubydoc.info/gems/ddtrace/Datadog/Tracing
          # Should match the global tags, but as a Hash.
          c.tags = {
            railsenv: Rails.env,
            service: service,
            container_name: container_name,
            pod_name: pod_name,
          }

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
