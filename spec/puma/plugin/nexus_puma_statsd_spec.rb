# frozen_string_literal: true

require "spec_helper"
require "puma"
require "puma/plugin/nexus_puma_statsd"
require_relative "../../support/fake_statsd"

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

  after { NexusSemanticLogger.metrics.statsd = nil }

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
    statsd = FakeStatsd.new
    NexusSemanticLogger.metrics.statsd = statsd
    stats = PumaStats.new({ workers: 2, booted_workers: 2, old_workers: 0, worker_status: [] })

    plugin.send(:notify_stats, stats, ["service:my-service"])

    gauges = statsd.calls.select { |call| call.first == :gauge }.map { |_, name, value, _| [name, value] }
    expect(gauges).to(contain_exactly(
      ["puma.workers", 2],
      ["puma.booted_workers", 2],
      ["puma.old_workers", 0],
      ["puma.running", 0],
      ["puma.backlog", 0],
      ["puma.pool_capacity", 0],
      ["puma.max_threads", 0],
    ))
    expect(statsd.calls).to(include([:count, "puma.requests_count", 0, { tags: ["service:my-service"] }]))
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
