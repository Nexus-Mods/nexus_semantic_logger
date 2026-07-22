# frozen_string_literal: true

require "spec_helper"
require "nexus_semantic_logger"
require_relative "../support/fake_statsd"

RSpec.describe(NexusSemanticLogger::LoggerMetricsSubscriber) do
  subject(:subscriber) { described_class.new }

  let(:statsd) { FakeStatsd.new }

  before { NexusSemanticLogger.metrics.statsd = statsd }
  after { NexusSemanticLogger.metrics.statsd = nil }

  def build_log(**attrs)
    SemanticLogger::Log.new("SpecLogger", :info).tap do |log|
      attrs.each { |key, value| log.public_send("#{key}=", value) }
    end
  end

  it "sends timing metrics for logs with a duration, tagged with the payload" do
    subscriber.call(build_log(metric: "spec.metric", duration: 12.5, payload: { foo: "bar" }))

    expect(statsd.calls).to(include([:timing, "spec.metric", 12.5, { tags: ["foo:bar"] }]))
  end

  it "increments a counter for metric logs without a duration" do
    subscriber.call(build_log(metric: "spec.count"))

    expect(statsd.calls).to(include([:increment, "spec.count", { tags: [] }]))
  end

  it "decrements when the metric amount is negative" do
    subscriber.call(build_log(metric: "spec.count", metric_amount: -1))

    expect(statsd.calls).to(include([:decrement, "spec.count", { tags: [] }]))
  end

  it "ignores logs without a metric" do
    subscriber.call(build_log(message: "no metric"))

    expect(statsd.calls).to(be_empty)
  end
end
