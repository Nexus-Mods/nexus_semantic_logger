# frozen_string_literal: true

require "rails_helper"
require "nexus_semantic_logger"

RSpec.describe(NexusSemanticLogger::AppenderFilter) do
  # The filter caches ENV lookups in class variables, so reset around every example.
  before { described_class.flush }
  after { described_class.flush }

  def stub_env(values)
    allow(ENV).to(receive(:fetch).and_call_original)
    values.each do |key, value|
      allow(ENV).to(receive(:fetch).with(key, anything).and_return(value))
      allow(ENV).to(receive(:fetch).with(key).and_return(value))
    end
  end

  def build_log(name, level)
    SemanticLogger::Log.new(name, level)
  end

  describe ".filter_lambda" do
    subject(:filter) { described_class.filter_lambda }

    it "appends logs at or above the default level" do
      stub_env("LOG_NAMES_DEFAULT_LEVEL" => "warn")

      expect(filter.call(build_log("Anything", :warn))).to(be(true))
      expect(filter.call(build_log("Anything", :error))).to(be(true))
    end

    it "drops logs below the default level" do
      stub_env("LOG_NAMES_DEFAULT_LEVEL" => "warn")

      expect(filter.call(build_log("Anything", :info))).to(be(false))
    end

    it "lets named loggers log at their overridden level below the default" do
      stub_env("LOG_NAMES_DEFAULT_LEVEL" => "warn", "LOG_NAMES_DEBUG" => "ChattyClass")

      expect(filter.call(build_log("ChattyClass", :debug))).to(be(true))
      expect(filter.call(build_log("OtherClass", :debug))).to(be(false))
    end

    it "always appends loggers named in the trace override" do
      stub_env("LOG_NAMES_DEFAULT_LEVEL" => "fatal", "LOG_NAMES_TRACE" => "Noisy,AlsoNoisy")

      expect(filter.call(build_log("Noisy", :trace))).to(be(true))
      expect(filter.call(build_log("AlsoNoisy", :debug))).to(be(true))
    end

    it "holds named loggers to their override even above the default level" do
      stub_env("LOG_NAMES_DEFAULT_LEVEL" => "debug", "LOG_NAMES_ERROR" => "Quiet")

      expect(filter.call(build_log("Quiet", :warn))).to(be(false))
      expect(filter.call(build_log("Quiet", :error))).to(be(true))
    end
  end

  describe ".flush" do
    it "clears cached ENV lookups so new values take effect" do
      stub_env("LOG_NAMES_DEFAULT_LEVEL" => "warn")
      expect(described_class.env_names_default_level).to(eq("warn"))

      stub_env("LOG_NAMES_DEFAULT_LEVEL" => "debug")
      expect(described_class.env_names_default_level).to(eq("warn"))

      described_class.flush
      expect(described_class.env_names_default_level).to(eq("debug"))
    end
  end

  describe ".get_next_log_level" do
    it "steps to the next level" do
      expect(described_class.get_next_log_level(:warn)).to(eq(:error))
    end

    it "wraps from fatal back to trace" do
      expect(described_class.get_next_log_level(:fatal)).to(eq(:trace))
    end
  end

  describe ".add_signal_handler" do
    after do
      Signal.trap("WINCH", "DEFAULT")
      Signal.trap("SYS", "DEFAULT")
    end

    it "cycles the default names level when the level signal arrives" do
      stub_env("LOG_NAMES_DEFAULT_LEVEL" => "warn")
      # Warm the cache first. Trap handlers cannot call rspec-mocks stubs because
      # mutexes are not allowed in trap context.
      described_class.env_names_default_level
      described_class.add_signal_handler

      Process.kill("WINCH", Process.pid)
      deadline = Time.now + 2
      sleep(0.05) while described_class.env_names_default_level == "warn" && Time.now < deadline

      expect(described_class.env_names_default_level).to(eq(:error))
    end
  end
end
