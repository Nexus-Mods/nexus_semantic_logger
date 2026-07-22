# frozen_string_literal: true

require "rails_helper"
require "nexus_semantic_logger"

RSpec.describe(NexusSemanticLogger::AppenderFilter) do
  def build_log(name, level)
    SemanticLogger::Log.new(name, level)
  end

  describe "#call" do
    it "appends logs at or above the default level" do
      filter = described_class.new(env: { "LOG_NAMES_DEFAULT_LEVEL" => "warn" })

      expect(filter.call(build_log("Anything", :warn))).to(be(true))
      expect(filter.call(build_log("Anything", :error))).to(be(true))
    end

    it "drops logs below the default level" do
      filter = described_class.new(env: { "LOG_NAMES_DEFAULT_LEVEL" => "warn" })

      expect(filter.call(build_log("Anything", :info))).to(be(false))
    end

    it "falls back to the supplied level when the env has no default" do
      filter = described_class.new(env: {}, fallback_level: :error)

      expect(filter.call(build_log("Anything", :warn))).to(be(false))
      expect(filter.call(build_log("Anything", :error))).to(be(true))
    end

    it "lets named loggers log at their overridden level below the default" do
      filter = described_class.new(env: {
        "LOG_NAMES_DEFAULT_LEVEL" => "warn",
        "LOG_NAMES_DEBUG" => "ChattyClass",
      })

      expect(filter.call(build_log("ChattyClass", :debug))).to(be(true))
      expect(filter.call(build_log("OtherClass", :debug))).to(be(false))
    end

    it "always appends loggers named in the trace override" do
      filter = described_class.new(env: {
        "LOG_NAMES_DEFAULT_LEVEL" => "fatal",
        "LOG_NAMES_TRACE" => "Noisy,AlsoNoisy",
      })

      expect(filter.call(build_log("Noisy", :trace))).to(be(true))
      expect(filter.call(build_log("AlsoNoisy", :debug))).to(be(true))
    end

    it "holds named loggers to their override even above the default level" do
      filter = described_class.new(env: {
        "LOG_NAMES_DEFAULT_LEVEL" => "debug",
        "LOG_NAMES_ERROR" => "Quiet",
      })

      expect(filter.call(build_log("Quiet", :warn))).to(be(false))
      expect(filter.call(build_log("Quiet", :error))).to(be(true))
    end
  end

  describe "#cycle_default_level!" do
    it "steps to the next level" do
      filter = described_class.new(env: { "LOG_NAMES_DEFAULT_LEVEL" => "warn" })

      filter.cycle_default_level!

      expect(filter.default_level).to(eq(:error))
    end

    it "wraps from fatal back to trace" do
      filter = described_class.new(env: { "LOG_NAMES_DEFAULT_LEVEL" => "fatal" })

      filter.cycle_default_level!

      expect(filter.default_level).to(eq(:trace))
    end
  end

  describe "#add_signal_handler" do
    after do
      Signal.trap("WINCH", "DEFAULT")
      Signal.trap("SYS", "DEFAULT")
    end

    it "cycles the default level when the level signal arrives" do
      filter = described_class.new(env: { "LOG_NAMES_DEFAULT_LEVEL" => "warn" })
      filter.add_signal_handler

      Process.kill("WINCH", Process.pid)
      deadline = Time.now + 2
      sleep(0.05) while filter.default_level == "warn" && Time.now < deadline

      expect(filter.default_level).to(eq(:error))
    end
  end

  describe "class level compatibility API" do
    after { described_class.flush }

    it "exposes the shared filter as a lambda" do
      NexusSemanticLogger.appender_filter = described_class.new(env: { "LOG_NAMES_DEFAULT_LEVEL" => "error" })

      filter = described_class.filter_lambda

      expect(filter).to(be_a(Proc))
      expect(filter.call(build_log("Anything", :warn))).to(be(false))
      expect(filter.call(build_log("Anything", :error))).to(be(true))
    end

    it "flush discards the shared instance so configuration is re-read" do
      NexusSemanticLogger.appender_filter = described_class.new(env: { "LOG_NAMES_DEFAULT_LEVEL" => "error" })

      described_class.flush

      expect(NexusSemanticLogger.appender_filter.default_level).not_to(eq("error"))
    end
  end
end
