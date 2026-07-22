# frozen_string_literal: true

require "rails_helper"
require "nexus_semantic_logger"

RSpec.describe(NexusSemanticLogger::DatadogTracer) do
  after do
    NexusSemanticLogger::DatadogSingleton.instance.statsd = nil
    Datadog.configuration.reset!
  end

  context "without a datadog agent configured" do
    it "does not create a statsd client" do
      described_class.new("my-service", env: {})

      expect(NexusSemanticLogger::DatadogSingleton.instance.statsd).to(be_nil)
    end

    it "quietens the datadog logger" do
      described_class.new("my-service", env: {})

      expect(Datadog.configuration.logger.level).to(eq(Logger::WARN))
    end
  end

  context "with an agent host configured" do
    let(:env) do
      {
        "DD_AGENT_HOST" => "agent.local",
        "CONTAINER_NAME" => "web-1",
        "POD_NAME" => "pod-1",
      }
    end

    it "creates a UDP statsd client with correlation tags" do
      described_class.new("my-service", env: env)

      statsd = NexusSemanticLogger::DatadogSingleton.instance.statsd
      expect(statsd).to(be_a(Datadog::Statsd))
      expect(statsd.host).to(eq("agent.local"))
      expect(statsd.port).to(eq(8125))
      expect(statsd.tags).to(contain_exactly("service:my-service", "container_name:web-1", "pod_name:pod-1"))
    end

    it "enables runtime metrics" do
      described_class.new("my-service", env: env)

      expect(Datadog.configuration.runtime_metrics.enabled).to(be(true))
    end

    it "tags traces to match the metric tags" do
      described_class.new("my-service", env: env)

      tags = Datadog.configuration.tags.transform_keys(&:to_s)
      expect(tags).to(include("service" => "my-service", "container_name" => "web-1", "pod_name" => "pod-1"))
    end

    it "disables tracing and profiling outside production" do
      described_class.new("my-service", env: env)

      expect(Datadog.configuration.tracing.enabled).to(be(false))
      expect(Datadog.configuration.profiling.enabled).to(be(false))
    end

    it "enables tracing and profiling when DD_FORCE_TRACER is true" do
      described_class.new("my-service", env: env.merge("DD_FORCE_TRACER" => "true"))

      expect(Datadog.configuration.tracing.enabled).to(be(true))
      expect(Datadog.configuration.profiling.enabled).to(be(true))
    end
  end

  context "with a statsd socket path configured" do
    let(:env) do
      {
        "DD_TRACE_AGENT_URL" => "unix:///var/run/datadog/apm.socket",
        "DD_STATSD_SOCKET_PATH" => "/var/run/datadog/dsd.socket",
      }
    end

    it "creates a UDS statsd client" do
      described_class.new("my-service", env: env)

      statsd = NexusSemanticLogger::DatadogSingleton.instance.statsd
      expect(statsd).to(be_a(Datadog::Statsd))
      expect(statsd.socket_path).to(eq("/var/run/datadog/dsd.socket"))
    end
  end
end
