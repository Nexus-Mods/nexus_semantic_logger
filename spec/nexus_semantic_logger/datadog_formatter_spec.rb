# frozen_string_literal: true

require "rails_helper"
require "nexus_semantic_logger/datadog_formatter"

# Covers the surface most exposed to the semantic_logger 4 to 5 change, so the widened
# dependency is verified against every Rails pairing in the CI matrix.
RSpec.describe(NexusSemanticLogger::DatadogFormatter) do
  subject(:formatter) { described_class.new("my-service") }

  # Appenders pass themselves as the logger argument.
  let(:appender) { Struct.new(:host, :application, :environment).new("spec-host", "app", "env") }

  let(:log) do
    SemanticLogger::Log.new("SpecLogger", :warn).tap do |l|
      l.message = "something happened"
      l.named_tags = { trace_id: "abc123" }
    end
  end

  it "emits Datadog shaped JSON" do
    hash = JSON.parse(formatter.call(log, appender))

    expect(hash).to(include(
      "status" => "warn",
      "service" => "my-service",
      "source" => "rails",
      "message" => "something happened",
    ))
    expect(hash).to(have_key("date"))
  end

  it "moves level to status and merges named tags into the root" do
    hash = JSON.parse(formatter.call(log, appender))

    expect(hash).not_to(have_key("level"))
    expect(hash).not_to(have_key("named_tags"))
    expect(hash["trace_id"]).to(eq("abc123"))
  end

  it "strips the application and environment attributes reserved by Datadog" do
    hash = JSON.parse(formatter.call(log, appender))

    expect(hash).not_to(have_key("application"))
    expect(hash).not_to(have_key("environment"))
  end

  describe "#hash_to_json" do
    it "drops keys that fail to serialise instead of raising" do
      bad = Object.new
      def bad.as_json(*)
        raise(SystemStackError)
      end

      def bad.to_json(*)
        raise(SystemStackError)
      end

      json = JSON.parse(formatter.hash_to_json({ good: "value", bad: bad }))

      expect(json["good"]).to(eq("value"))
      expect(json).not_to(have_key("bad"))
      expect(json["as_json_serialise_errors"]).to(eq(["bad"]))
    end
  end
end
