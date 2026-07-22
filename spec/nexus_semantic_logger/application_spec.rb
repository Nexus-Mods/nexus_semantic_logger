# frozen_string_literal: true

require "rails_helper"
require "nexus_semantic_logger"

RSpec.describe(NexusSemanticLogger::Application) do
  let(:appender) { double("appender", :filter= => nil) }
  let(:sl_config) { double("semantic logger config", add_appender: appender, clear_appenders!: nil) }
  let(:config) do
    ActiveSupport::OrderedOptions.new.tap do |c|
      c.rails_semantic_logger = ActiveSupport::OrderedOptions.new
      c.semantic_logger = sl_config
    end
  end

  before do
    allow(SemanticLogger).to(receive(:sync!))
    allow(SemanticLogger).to(receive(:on_log))
    allow(NexusSemanticLogger::DatadogTracer).to(receive(:new))
    allow(NexusSemanticLogger::AppenderFilter).to(receive(:add_signal_handler))
    allow(ENV).to(receive(:fetch).and_call_original)
    allow(ENV).to(receive(:[]).and_call_original)
  end

  describe ".common" do
    it "defaults the log level to WARN" do
      allow(ENV).to(receive(:fetch).with("LOG_LEVEL", "WARN").and_return("WARN"))

      described_class.common(config, "my-service")

      expect(config.log_level).to(eq("WARN"))
    end

    it "respects LOG_LEVEL from the environment" do
      allow(ENV).to(receive(:fetch).with("LOG_LEVEL", "WARN").and_return("INFO"))

      described_class.common(config, "my-service")

      expect(config.log_level).to(eq("INFO"))
    end

    it "configures datadog correlation log tags" do
      described_class.common(config, "my-service")

      expect(config.log_tags[:request_id]).to(eq(:request_id))
      expect(config.log_tags[:ddsource]).to(eq(["ruby"]))

      correlation = config.log_tags[:dd].call(nil)
      expect(correlation.keys).to(contain_exactly(:trace_id, :span_id, :env, :service, :version))
    end

    it "uses the datadog formatter for a stdout appender with the name filter" do
      expect(sl_config).to(receive(:add_appender)) do |io:, formatter:|
        expect(io).to(be($stdout))
        expect(formatter).to(be_a(NexusSemanticLogger::DatadogFormatter))
        appender
      end
      expect(appender).to(receive(:filter=))

      described_class.common(config, "my-service")

      expect(config.rails_semantic_logger.format).to(be_a(NexusSemanticLogger::DatadogFormatter))
      expect(config.rails_semantic_logger.add_file_appender).to(be(false))
    end

    it "enables synchronous logging before adding appenders" do
      expect(SemanticLogger).to(receive(:sync!).ordered)
      expect(sl_config).to(receive(:add_appender).ordered.and_return(appender))

      described_class.common(config, "my-service")
    end

    it "starts the datadog tracer and metrics subscriber" do
      expect(NexusSemanticLogger::DatadogTracer).to(receive(:new).with("my-service"))
      expect(SemanticLogger).to(receive(:on_log).with(an_instance_of(NexusSemanticLogger::LoggerMetricsSubscriber)))
      expect(NexusSemanticLogger::AppenderFilter).to(receive(:add_signal_handler))

      described_class.common(config, "my-service")
    end
  end

  describe ".development" do
    it "defaults the log level to DEBUG and switches to a colour appender" do
      allow(ENV).to(receive(:fetch).with("LOG_LEVEL", "DEBUG").and_return("DEBUG"))
      expect(sl_config).to(receive(:clear_appenders!))
      expect(sl_config).to(receive(:add_appender).with(io: $stdout, formatter: :color).and_return(appender))

      described_class.development(config)

      expect(config.log_level).to(eq("DEBUG"))
    end

    it "adds a TCP datadog appender when a local agent is configured" do
      allow(ENV).to(receive(:[]).with("DD_AGENT_HOST").and_return("agent.local"))
      allow(ENV).to(receive(:[]).with("DD_AGENT_LOGGING_PORT").and_return("10518"))
      config.rails_semantic_logger.format = NexusSemanticLogger::DatadogFormatter.new("my-service")

      expect(sl_config).to(receive(:add_appender).with(io: $stdout, formatter: :color).and_return(appender))
      expect(sl_config).to(receive(:add_appender).with(
        appender: :tcp,
        server: "agent.local:10518",
        formatter: config.rails_semantic_logger.format,
      ).and_return(appender))

      described_class.development(config)
    end
  end

  describe ".test" do
    it "switches to a colour appender with the name filter" do
      expect(sl_config).to(receive(:clear_appenders!))
      expect(sl_config).to(receive(:add_appender).with(io: $stdout, formatter: :color).and_return(appender))
      expect(appender).to(receive(:filter=))

      described_class.test(config)
    end
  end
end
