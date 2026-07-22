# frozen_string_literal: true

require "rails_helper"
require "nexus_semantic_logger"

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
    let(:statsd) { instance_double(Datadog::Statsd, flush: nil) }
    let(:sync) { Rails.env.development? }

    before { singleton.statsd = statsd }

    it "delegates increment and flushes" do
      expect(statsd).to(receive(:increment).with("metric", tags: ["a:b"]))
      expect(statsd).to(receive(:flush).with(sync: sync))

      singleton.increment("metric", tags: ["a:b"])
    end

    it "delegates decrement" do
      expect(statsd).to(receive(:decrement).with("metric", tags: []))

      singleton.decrement("metric")
    end

    it "delegates timing" do
      expect(statsd).to(receive(:timing).with("metric", 12, tags: []))

      singleton.timing("metric", 12)
    end

    it "delegates distribution, gauge and count" do
      expect(statsd).to(receive(:distribution).with("metric", 1.5, tags: []))
      expect(statsd).to(receive(:gauge).with("metric", 7, tags: []))
      expect(statsd).to(receive(:count).with("metric", 3, tags: []))

      singleton.distribution("metric", 1.5)
      singleton.gauge("metric", 7)
      singleton.count("metric", 3)
    end

    it "treats nil tags as an empty tag list" do
      expect(statsd).to(receive(:increment).with("metric", tags: []))

      singleton.increment("metric", tags: nil)
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
