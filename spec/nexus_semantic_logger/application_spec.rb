# frozen_string_literal: true

require "rails_helper"
require "nexus_semantic_logger"
require "socket"

RSpec.describe(NexusSemanticLogger::Application) do
  let(:config) do
    ActiveSupport::OrderedOptions.new.tap do |c|
      c.rails_semantic_logger = ActiveSupport::OrderedOptions.new
      c.semantic_logger = SemanticLogger
    end
  end

  let!(:appenders_before) { SemanticLogger.appenders.to_a }

  after do
    (SemanticLogger.appenders.to_a - appenders_before).each { |a| SemanticLogger.remove_appender(a) }
    NexusSemanticLogger.metrics = nil
    Datadog.configuration.reset!
    Signal.trap("WINCH", "DEFAULT")
    Signal.trap("SYS", "DEFAULT")
  end

  def added_appenders
    SemanticLogger.appenders.to_a - appenders_before
  end

  describe ".common" do
    it "defaults the log level to WARN" do
      described_class.common(config, "my-service", env: {})

      expect(config.log_level).to(eq("WARN"))
    end

    it "respects LOG_LEVEL from the environment" do
      described_class.common(config, "my-service", env: { "LOG_LEVEL" => "INFO" })

      expect(config.log_level).to(eq("INFO"))
    end

    it "configures datadog correlation log tags" do
      described_class.common(config, "my-service", env: {})

      expect(config.log_tags[:request_id]).to(eq(:request_id))
      expect(config.log_tags[:ddsource]).to(eq(["ruby"]))

      correlation = config.log_tags[:dd].call(nil)
      expect(correlation.keys).to(contain_exactly(:trace_id, :span_id, :env, :service, :version))
    end

    it "adds a stdout appender in datadog format, filtered by the policy" do
      described_class.common(config, "my-service", env: {})

      appender = added_appenders.fetch(0)
      expect(appender.formatter).to(be_a(NexusSemanticLogger::DatadogFormatter))
      expect(appender.filter).to(be_a(Proc))
      expect(config.rails_semantic_logger.format).to(be(appender.formatter))
      expect(config.rails_semantic_logger.add_file_appender).to(be(false))
    end

    it "carries the policy on the config, built from the supplied env" do
      described_class.common(config, "my-service", env: { "LOG_NAMES_DEFAULT_LEVEL" => "error" })

      expect(config.nexus_semantic_logger.level_policy.default_level).to(eq(:error))
    end

    it "sends metric tagged logs to statsd" do
      statsd = instance_spy(Datadog::Statsd)
      NexusSemanticLogger.metrics.statsd = statsd
      described_class.common(config, "my-service", env: {})

      SemanticLogger["MetricsSpec"].info("something happened", metric: "spec.event")

      # SemanticLogger.on_log subscribers cannot be deregistered, so earlier
      # examples that ran common leave theirs behind and each one fires.
      expect(statsd).to(have_received(:increment).with("spec.event", tags: []).at_least(:once))
    end

    it "cycles the policy level and announces it when the level signal arrives" do
      described_class.common(config, "my-service", env: { "LOG_NAMES_DEFAULT_LEVEL" => "warn" })
      policy = config.nexus_semantic_logger.level_policy

      expect do
        Process.kill("WINCH", Process.pid)
        deadline = Time.now + 2
        sleep(0.05) while policy.default_level == :warn && Time.now < deadline
      end.to(output(/changed LOG_NAMES_DEFAULT_LEVEL from warn to error/).to_stdout)

      expect(policy.default_level).to(eq(:error))
    end

    it "reports the levels when the info signal arrives" do
      described_class.common(config, "my-service", env: { "LOG_NAMES_DEFAULT_LEVEL" => "warn" })

      expect do
        Process.kill("SYS", Process.pid)
        sleep(0.2)
      end.to(output(/SYS signal reports LOG_LEVEL=WARN LOG_NAMES_DEFAULT_LEVEL=warn/).to_stdout)
    end
  end

  describe ".development" do
    it "defaults the log level to DEBUG and switches to a colour appender" do
      described_class.development(config, env: {})

      expect(config.log_level).to(eq("DEBUG"))
      appender = added_appenders.fetch(0)
      expect(appender.formatter).to(be_a(SemanticLogger::Formatters::Color))
      expect(appender.filter).to(be_a(Proc))
    end

    it "reuses the policy that common placed on the config" do
      described_class.common(config, "my-service", env: { "LOG_NAMES_DEFAULT_LEVEL" => "error" })
      policy = config.nexus_semantic_logger.level_policy

      described_class.development(config, env: {})

      expect(config.nexus_semantic_logger.level_policy).to(be(policy))
    end

    it "connects a TCP datadog appender when a local agent is configured" do
      server = TCPServer.new("127.0.0.1", 0)
      port = server.addr[1]
      config.rails_semantic_logger.format = NexusSemanticLogger::DatadogFormatter.new("my-service")

      described_class.development(
        config,
        env: { "DD_AGENT_HOST" => "127.0.0.1", "DD_AGENT_LOGGING_PORT" => port.to_s },
      )

      tcp_appender = added_appenders.find { |a| a.is_a?(SemanticLogger::Appender::Tcp) }
      expect(tcp_appender).not_to(be_nil)
      expect(tcp_appender.formatter).to(be(config.rails_semantic_logger.format))
      expect(IO.select([server], nil, nil, 2)).not_to(be_nil)
    ensure
      server&.close
    end
  end

  describe ".test" do
    it "switches to a colour appender filtered by the policy" do
      described_class.test(config, env: {})

      appender = added_appenders.fetch(0)
      expect(appender.formatter).to(be_a(SemanticLogger::Formatters::Color))
      expect(appender.filter).to(be_a(Proc))
    end
  end

  describe "rails_semantic_logger compatibility warning" do
    let(:io) { StringIO.new }

    before { SemanticLogger.add_appender(io: io) }

    def warning_output
      described_class.send(:warn_on_incompatible_rails_semantic_logger)
      SemanticLogger.flush
      io.string
    end

    it "warns when RuntimeRegistry lacks sql_runtime on rails_semantic_logger 4.x" do
      stub_const("ActiveRecord::RuntimeRegistry", Module.new)
      stub_const("RailsSemanticLogger::VERSION", "4.17.0")

      expect(warning_output).to(match(/rails_semantic_logger", ">= 5.1"/))
    end

    it "stays quiet when sql_runtime is available" do
      registry = Module.new do
        def self.sql_runtime
          0.0
        end
      end
      stub_const("ActiveRecord::RuntimeRegistry", registry)
      stub_const("RailsSemanticLogger::VERSION", "4.17.0")

      expect(warning_output).to(be_empty)
    end

    it "stays quiet on rails_semantic_logger 5.x" do
      stub_const("ActiveRecord::RuntimeRegistry", Module.new)
      stub_const("RailsSemanticLogger::VERSION", "5.1.0")

      expect(warning_output).to(be_empty)
    end

    it "stays quiet when ActiveRecord is not loaded" do
      expect(warning_output).to(be_empty)
    end
  end
end
