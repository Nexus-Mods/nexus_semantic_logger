# frozen_string_literal: true

require "rails_helper"
require "nexus_semantic_logger"
require_relative "../support/fake_statsd"

RSpec.describe(NexusSemanticLogger::DatadogSingleton) do
  subject(:singleton) { described_class.instance }

  after { singleton.statsd = nil }

  context "when no statsd instance is configured" do
    before { singleton.statsd = nil }

    it "silently ignores metrics" do
      expect { singleton.increment("metric") }.not_to(raise_error)
      expect { singleton.timing("metric", 5) }.not_to(raise_error)
      expect { singleton.flush }.not_to(raise_error)
    end
  end

  context "when a statsd instance is configured" do
    let(:statsd) { FakeStatsd.new }

    before { singleton.statsd = statsd }

    it "delegates increment and flushes, forcing sync in development" do
      singleton.increment("metric", tags: ["a:b"])

      expect(statsd.calls).to(eq([
        [:increment, "metric", { tags: ["a:b"] }],
        [:flush, { sync: Rails.env.development? }],
      ]))
    end

    it "delegates decrement" do
      singleton.decrement("metric")

      expect(statsd.calls).to(include([:decrement, "metric", { tags: [] }]))
    end

    it "delegates timing" do
      singleton.timing("metric", 12)

      expect(statsd.calls).to(include([:timing, "metric", 12, { tags: [] }]))
    end

    it "delegates distribution, gauge and count" do
      singleton.distribution("metric", 1.5)
      singleton.gauge("metric", 7)
      singleton.count("metric", 3)

      expect(statsd.calls).to(include(
        [:distribution, "metric", 1.5, { tags: [] }],
        [:gauge, "metric", 7, { tags: [] }],
        [:count, "metric", 3, { tags: [] }],
      ))
    end

    it "treats nil tags as an empty tag list" do
      singleton.increment("metric", tags: nil)

      expect(statsd.calls).to(include([:increment, "metric", { tags: [] }]))
    end
  end
end

RSpec.describe(NexusSemanticLogger) do
  it "exposes the datadog singleton as the metrics object" do
    expect(described_class.metrics).to(be(NexusSemanticLogger::DatadogSingleton.instance))
  end

  it "exposes a memoized traced shell" do
    expect(described_class.shell).to(be_a(NexusSemanticLogger::TracedShell))
    expect(described_class.shell).to(be(described_class.shell))
  end

  it "patches SemanticLogger levels access" do
    expect(SemanticLogger::Levels.all_levels).to(eq(SemanticLogger::Levels::LEVELS))
  end
end
