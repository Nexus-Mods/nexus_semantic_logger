# frozen_string_literal: true

require "spec_helper"
require "nexus_semantic_logger"

RSpec.describe(NexusSemanticLogger::LoggerMetricsSubscriber) do
  subject(:subscriber) { described_class.new }

  let(:statsd) { instance_spy(Datadog::Statsd) }

  before { NexusSemanticLogger.metrics.statsd = statsd }
  after { NexusSemanticLogger.metrics = nil }

  def build_log(**attrs)
    SemanticLogger::Log.new("SpecLogger", :info).tap do |log|
      attrs.each { |key, value| log.public_send("#{key}=", value) }
    end
  end

  it "sends timing metrics for logs with a duration, tagged with the payload" do
    subscriber.call(build_log(metric: "spec.metric", duration: 12.5, payload: { foo: "bar" }))

    expect(statsd).to(have_received(:timing).with("spec.metric", 12.5, tags: ["foo:bar"]))
  end

  it "increments a counter for metric logs without a duration" do
    subscriber.call(build_log(metric: "spec.count"))

    expect(statsd).to(have_received(:increment).with("spec.count", tags: []))
  end

  it "decrements when the metric amount is negative" do
    subscriber.call(build_log(metric: "spec.count", metric_amount: -1))

    expect(statsd).to(have_received(:decrement).with("spec.count", tags: []))
  end

  it "ignores logs without a metric" do
    subscriber.call(build_log(message: "no metric"))

    expect(statsd).not_to(have_received(:increment))
    expect(statsd).not_to(have_received(:timing))
  end
end
