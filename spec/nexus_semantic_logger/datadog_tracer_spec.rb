# frozen_string_literal: true

require "rails_helper"
require "nexus_semantic_logger"

RSpec.describe(NexusSemanticLogger::DatadogTracer) do
  let(:tracing) { double("tracing", :enabled= => nil, instrument: nil) }
  let(:runtime_metrics) { double("runtime_metrics", :enabled= => nil, :statsd= => nil) }
  let(:profiling) { double("profiling", :enabled= => nil) }
  let(:dd_logger) { double("datadog logger", :level= => nil) }
  let(:datadog_config) do
    double(
      "datadog config",
      tracing: tracing,
      runtime_metrics: runtime_metrics,
      profiling: profiling,
      logger: dd_logger,
      :tags= => nil,
    )
  end
  let(:statsd) { instance_double(Datadog::Statsd) }

  before do
    allow(Datadog).to(receive(:configure).and_yield(datadog_config))
    allow(Datadog::Statsd).to(receive(:new).and_return(statsd))
  end

  after { NexusSemanticLogger::DatadogSingleton.instance.statsd = nil }

  context "without a datadog agent configured" do
    it "does not create a statsd client or enable runtime metrics" do
      expect(Datadog::Statsd).not_to(receive(:new))
      expect(runtime_metrics).not_to(receive(:enabled=))

      described_class.new("my-service", env: {})
    end

    it "still instruments rails and quietens the datadog logger" do
      expect(tracing).to(receive(:instrument).with(:rails, hash_including(service_name: "my-service")))
      expect(dd_logger).to(receive(:level=).with(Logger::WARN))

      described_class.new("my-service", env: {})
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
      expect(Datadog::Statsd).to(receive(:new).with(
        "agent.local",
        8125,
        tags: ["service:my-service", "container_name:web-1", "pod_name:pod-1"],
      ).and_return(statsd))

      described_class.new("my-service", env: env)
    end

    it "enables runtime metrics with the shared statsd client" do
      expect(runtime_metrics).to(receive(:enabled=).with(true))
      expect(runtime_metrics).to(receive(:statsd=).with(statsd))

      described_class.new("my-service", env: env)
      expect(NexusSemanticLogger::DatadogSingleton.instance.statsd).to(be(statsd))
    end

    it "tags traces to match the metric tags" do
      expect(datadog_config).to(receive(:tags=).with(
        { service: "my-service", container_name: "web-1", pod_name: "pod-1" },
      ))

      described_class.new("my-service", env: env)
    end

    it "disables tracing and profiling outside production" do
      expect(tracing).to(receive(:enabled=).with(false))
      expect(profiling).to(receive(:enabled=).with(false))

      described_class.new("my-service", env: env)
    end

    it "enables tracing and profiling when DD_FORCE_TRACER is true" do
      expect(tracing).to(receive(:enabled=).with(true))
      expect(profiling).to(receive(:enabled=).with(true))

      described_class.new("my-service", env: env.merge("DD_FORCE_TRACER" => "true"))
    end
  end

  context "with a statsd socket path configured" do
    let(:env) do
      {
        "DD_TRACE_AGENT_URL" => "unix:///var/run/datadog/apm.socket",
        "DD_STATSD_SOCKET_PATH" => "/var/run/datadog/dsd.socket",
        "CONTAINER_NAME" => "web-1",
        "POD_NAME" => "pod-1",
      }
    end

    it "creates a UDS statsd client" do
      expect(Datadog::Statsd).to(receive(:new).with(
        socket_path: "/var/run/datadog/dsd.socket",
        tags: ["service:my-service", "container_name:web-1", "pod_name:pod-1"],
      ).and_return(statsd))

      described_class.new("my-service", env: env)
    end
  end
end
