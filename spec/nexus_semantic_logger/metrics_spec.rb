# frozen_string_literal: true

require "spec_helper"
require "nexus_semantic_logger"

RSpec.describe(NexusSemanticLogger::Metrics) do
  let(:statsd) { instance_spy(Datadog::Statsd) }

  context "when no statsd instance is configured" do
    subject(:metrics) { described_class.new }

    it "defaults to a noop statsd and silently ignores metrics" do
      expect(metrics.statsd).to(be_a(NexusSemanticLogger::Metrics::NoopStatsd))
      expect { metrics.increment("metric") }.not_to(raise_error)
      expect { metrics.timing("metric", 5) }.not_to(raise_error)
      expect { metrics.flush }.not_to(raise_error)
    end
  end

  context "with a statsd instance" do
    subject(:metrics) { described_class.new(statsd: statsd) }

    it "delegates increment and flushes" do
      metrics.increment("metric", tags: ["a:b"])

      expect(statsd).to(have_received(:increment).with("metric", tags: ["a:b"]))
      expect(statsd).to(have_received(:flush).with(sync: false))
    end

    it "delegates decrement" do
      metrics.decrement("metric")

      expect(statsd).to(have_received(:decrement).with("metric", tags: []))
    end

    it "delegates timing" do
      metrics.timing("metric", 12)

      expect(statsd).to(have_received(:timing).with("metric", 12, tags: []))
    end

    it "delegates distribution, gauge and count" do
      metrics.distribution("metric", 1.5)
      metrics.gauge("metric", 7)
      metrics.count("metric", 3)

      expect(statsd).to(have_received(:distribution).with("metric", 1.5, tags: []))
      expect(statsd).to(have_received(:gauge).with("metric", 7, tags: []))
      expect(statsd).to(have_received(:count).with("metric", 3, tags: []))
    end

    it "treats nil tags as an empty tag list" do
      metrics.increment("metric", tags: nil)

      expect(statsd).to(have_received(:increment).with("metric", tags: []))
    end
  end

  context "with synchronous flushing" do
    subject(:metrics) { described_class.new(statsd: statsd, sync_flush: true) }

    it "forces flushes to be synchronous" do
      metrics.increment("metric")

      expect(statsd).to(have_received(:flush).with(sync: true))
    end
  end
end

RSpec.describe(NexusSemanticLogger) do
  after { described_class.metrics = nil }

  it "memoizes a noop metrics object by default" do
    expect(described_class.metrics).to(be_a(NexusSemanticLogger::Metrics))
    expect(described_class.metrics).to(be(described_class.metrics))
    expect(described_class.metrics.statsd).to(be_a(NexusSemanticLogger::Metrics::NoopStatsd))
  end

  it "exposes the shared metrics object under the deprecated singleton name" do
    expect(NexusSemanticLogger::DatadogSingleton.instance).to(be(described_class.metrics))
  end

  it "exposes a memoized traced shell" do
    expect(described_class.shell).to(be_a(NexusSemanticLogger::TracedShell))
    expect(described_class.shell).to(be(described_class.shell))
  end

  it "patches SemanticLogger levels access" do
    expect(SemanticLogger::Levels.all_levels).to(eq(SemanticLogger::Levels::LEVELS))
  end
end
