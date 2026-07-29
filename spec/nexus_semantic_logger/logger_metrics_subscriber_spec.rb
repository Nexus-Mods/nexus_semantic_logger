# frozen_string_literal: true

require "spec_helper"
require "nexus_semantic_logger"

# Covers the surface most exposed to the semantic_logger 4 to 5 change, so the widened
# dependency is verified against every Rails pairing in the CI matrix.
RSpec.describe(NexusSemanticLogger::LoggerMetricsSubscriber) do
  subject(:subscriber) { described_class.new }

  let(:metrics) { instance_double(NexusSemanticLogger::DatadogSingleton) }

  before { allow(NexusSemanticLogger).to(receive(:metrics).and_return(metrics)) }

  def build_log(**attrs)
    SemanticLogger::Log.new("SpecLogger", :info).tap do |log|
      attrs.each { |key, value| log.public_send("#{key}=", value) }
    end
  end

  it "sends timing metrics for logs with a duration, tagged with the payload" do
    expect(metrics).to(receive(:timing).with("spec.metric", 12.5, tags: ["foo:bar"]))

    subscriber.call(build_log(metric: "spec.metric", duration: 12.5, payload: { foo: "bar" }))
  end

  it "increments a counter for metric logs without a duration" do
    expect(metrics).to(receive(:increment).with("spec.count", tags: nil))

    subscriber.call(build_log(metric: "spec.count"))
  end

  it "decrements when the metric amount is negative" do
    expect(metrics).to(receive(:decrement).with("spec.count", tags: nil))

    subscriber.call(build_log(metric: "spec.count", metric_amount: -1))
  end

  it "ignores logs without a metric" do
    expect(metrics).not_to(receive(:increment))
    expect(metrics).not_to(receive(:timing))

    subscriber.call(build_log(message: "no metric"))
  end
end
