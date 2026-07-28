# frozen_string_literal: true

require "rails_helper"
require "nexus_semantic_logger"

RSpec.describe(NexusSemanticLogger::LevelPolicy) do
  def build_log(name, level)
    SemanticLogger::Log.new(name, level)
  end

  describe ".from_env" do
    it "reads the default level from the env" do
      policy = described_class.from_env({ "LOG_NAMES_DEFAULT_LEVEL" => "warn" })

      expect(policy.default_level).to(eq(:warn))
    end

    it "falls back to the supplied level when the env has no default" do
      policy = described_class.from_env({}, fallback_level: :error)

      expect(policy.default_level).to(eq(:error))
    end

    it "defaults to warn with no env value and no fallback" do
      policy = described_class.from_env({})

      expect(policy.default_level).to(eq(:warn))
    end

    it "parses comma separated name overrides per level" do
      policy = described_class.from_env({
        "LOG_NAMES_DEBUG" => "ChattyClass,OtherChatty",
        "LOG_NAMES_ERROR" => "Quiet",
      })

      expect(policy.overrides).to(eq({
        "ChattyClass" => :debug,
        "OtherChatty" => :debug,
        "Quiet" => :error,
      }))
    end

    it "keeps the most verbose level for a name in several lists" do
      policy = described_class.from_env({
        "LOG_NAMES_TRACE" => "Contested",
        "LOG_NAMES_FATAL" => "Contested",
      })

      expect(policy.overrides).to(eq({ "Contested" => :trace }))
    end
  end

  describe "#call" do
    it "appends logs at or above the default level" do
      policy = described_class.new(default_level: :warn)

      expect(policy.call(build_log("Anything", :warn))).to(be(true))
      expect(policy.call(build_log("Anything", :error))).to(be(true))
    end

    it "drops logs below the default level" do
      policy = described_class.new(default_level: :warn)

      expect(policy.call(build_log("Anything", :info))).to(be(false))
    end

    it "lets overridden loggers log below the default level" do
      policy = described_class.new(default_level: :warn, overrides: { "ChattyClass" => :debug })

      expect(policy.call(build_log("ChattyClass", :debug))).to(be(true))
      expect(policy.call(build_log("OtherClass", :debug))).to(be(false))
    end

    it "holds overridden loggers to their level even above the default" do
      policy = described_class.new(default_level: :debug, overrides: { "Quiet" => :error })

      expect(policy.call(build_log("Quiet", :warn))).to(be(false))
      expect(policy.call(build_log("Quiet", :error))).to(be(true))
    end

    it "always appends loggers overridden to trace" do
      policy = described_class.new(default_level: :fatal, overrides: { "Noisy" => :trace })

      expect(policy.call(build_log("Noisy", :trace))).to(be(true))
    end
  end

  describe "#to_proc" do
    it "wraps the policy for appenders that require a Proc" do
      policy = described_class.new(default_level: :warn)

      expect(policy.to_proc).to(be_a(Proc))
      expect(policy.to_proc.call(build_log("Anything", :error))).to(be(true))
    end
  end

  describe "#cycle_default_level!" do
    it "steps to the next level" do
      policy = described_class.new(default_level: :warn)

      policy.cycle_default_level!

      expect(policy.default_level).to(eq(:error))
    end

    it "wraps from fatal back to trace" do
      policy = described_class.new(default_level: :fatal)

      policy.cycle_default_level!

      expect(policy.default_level).to(eq(:trace))
    end
  end

  describe "level normalization" do
    it "accepts strings, symbols and mixed case" do
      expect(described_class.new(default_level: "WARN").default_level).to(eq(:warn))
      expect(described_class.new(default_level: :warn).default_level).to(eq(:warn))
      expect(described_class.new(default_level: "Error").default_level).to(eq(:error))
      expect(described_class.new(default_level: :warn, overrides: { "A" => "DEBUG" }).overrides["A"]).to(eq(:debug))
    end
  end
end
