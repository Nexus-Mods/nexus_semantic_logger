# frozen_string_literal: true

require "spec_helper"
require "puma"
require "puma/plugin/nexus_puma_statsd"

RSpec.describe(PumaStats) do
  # Shapes mirror Puma::Server#stats and Puma::Cluster#stats as of puma 8.
  let(:single_stats) do
    {
      started_at: "2026-07-22T09:00:00Z",
      backlog: 1,
      running: 5,
      pool_capacity: 4,
      max_threads: 5,
      requests_count: 123,
    }
  end

  let(:clustered_stats) do
    {
      started_at: "2026-07-22T09:00:00Z",
      workers: 2,
      phase: 0,
      booted_workers: 2,
      old_workers: 1,
      worker_status: [
        {
          pid: 101, index: 0, phase: 0, booted: true,
          last_status: { backlog: 1, running: 5, pool_capacity: 3, max_threads: 5, requests_count: 10 }
        },
        {
          pid: 102, index: 1, phase: 0, booted: true,
          last_status: { backlog: 2, running: 5, pool_capacity: 4, max_threads: 5, requests_count: 32 }
        },
      ],
    }
  end

  it "reads single mode stats directly" do
    stats = described_class.new(single_stats)

    expect(stats.clustered?).to(be(false))
    expect(stats.workers).to(eq(1))
    expect(stats.booted_workers).to(eq(1))
    expect(stats.old_workers).to(eq(0))
    expect(stats.running).to(eq(5))
    expect(stats.backlog).to(eq(1))
    expect(stats.pool_capacity).to(eq(4))
    expect(stats.max_threads).to(eq(5))
    expect(stats.requests_count).to(eq(123))
  end

  it "aggregates clustered stats across workers" do
    stats = described_class.new(clustered_stats)

    expect(stats.clustered?).to(be(true))
    expect(stats.workers).to(eq(2))
    expect(stats.booted_workers).to(eq(2))
    expect(stats.old_workers).to(eq(1))
    expect(stats.running).to(eq(10))
    expect(stats.backlog).to(eq(3))
    expect(stats.pool_capacity).to(eq(7))
    expect(stats.max_threads).to(eq(10))
    expect(stats.requests_count).to(eq(42))
  end
end

RSpec.describe("nexus_puma_statsd plugin") do
  let(:plugin_class) { Puma::Plugins.find("nexus_puma_statsd") }
  let(:plugin) { plugin_class.new }

  after { NexusSemanticLogger.metrics = nil }

  it "registers with puma's plugin registry" do
    expect(plugin_class).not_to(be_nil)
    expect(plugin).to(respond_to(:start))
  end

  it "starts against a real puma launcher surface" do
    log_writer = Puma::LogWriter.new(StringIO.new, StringIO.new)
    launcher = Struct.new(:log_writer).new(log_writer)

    expect { plugin.start(launcher) }.not_to(raise_error)
  end

  it "emits every puma metric from a stats snapshot" do
    statsd = instance_spy(Datadog::Statsd)
    NexusSemanticLogger.metrics.statsd = statsd
    stats = PumaStats.new({ workers: 2, booted_workers: 2, old_workers: 0, worker_status: [] })
    tags = ["service:my-service"]

    plugin.send(:notify_stats, stats, tags)

    expect(statsd).to(have_received(:gauge).with("puma.workers", 2, tags: tags))
    expect(statsd).to(have_received(:gauge).with("puma.booted_workers", 2, tags: tags))
    expect(statsd).to(have_received(:gauge).with("puma.old_workers", 0, tags: tags))
    expect(statsd).to(have_received(:gauge).with("puma.running", 0, tags: tags))
    expect(statsd).to(have_received(:gauge).with("puma.backlog", 0, tags: tags))
    expect(statsd).to(have_received(:gauge).with("puma.pool_capacity", 0, tags: tags))
    expect(statsd).to(have_received(:gauge).with("puma.max_threads", 0, tags: tags))
    expect(statsd).to(have_received(:count).with("puma.requests_count", 0, tags: tags))
  end

  describe "tags from the environment" do
    it "collects datadog unified service tags" do
      stub_const("ENV", ENV.to_h.merge(
        "HOSTNAME" => "pod-1",
        "DD_ENV" => "production",
        "DD_SERVICE" => "my-service",
        "DD_VERSION" => "1.2.3",
      ))

      tags = plugin.send(:environment_variable_tags)

      expect(tags).to(include("pod_name:pod-1", "env:production", "service:my-service", "version:1.2.3"))
    end

    it "returns nil when nothing relevant is set" do
      stub_const("ENV", ENV.to_h.reject { |k, _| k.start_with?("DD_", "HOSTNAME") })

      expect(plugin.send(:environment_variable_tags)).to(be_nil)
    end
  end
end
