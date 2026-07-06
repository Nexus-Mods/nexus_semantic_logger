# frozen_string_literal: true

require "spec_helper"
require "nexus_semantic_logger"

RSpec.describe(NexusSemanticLogger::TracedShell) do
  subject(:shell) { described_class.new }

  # Spans are still created (and traced code paths exercised); this just stops the datadog gem
  # trying to flush them to a local agent and logging ECONNREFUSED noise.
  before(:context) { Datadog.configure { |c| c.tracing.enabled = false } }

  let(:metrics) do
    instance_double(NexusSemanticLogger::DatadogSingleton, timing: nil, increment: nil, distribution: nil)
  end

  before do
    allow(NexusSemanticLogger).to(receive(:metrics).and_return(metrics))
    allow(shell.logger).to(receive(:info))
  end

  describe "#capture3" do
    it "returns stdout, stderr and status like Open3.capture3" do
      stdout, stderr, status = shell.capture3("sh", "-c", "echo out; echo err >&2")

      expect(stdout).to(eq("out\n"))
      expect(stderr).to(eq("err\n"))
      expect(status).to(be_success)
    end

    it "passes stdin_data to the child" do
      stdout, _stderr, status = shell.capture3("cat", stdin_data: "hello")

      expect(stdout).to(eq("hello"))
      expect(status).to(be_success)
    end

    it "emits duration and execution metrics tagged with the binary and outcome" do
      shell.capture3("sh", "-c", "true")

      expect(metrics).to(have_received(:timing)
        .with("nexus.shell.duration_ms", kind_of(Integer), tags: ["command:sh", "outcome:success"]))
      expect(metrics).to(have_received(:increment)
        .with("nexus.shell.executions", tags: ["command:sh", "outcome:success"]))
    end

    it "tags a non-zero exit as outcome:failure and preserves the exit status" do
      _stdout, _stderr, status = shell.capture3("sh", "-c", "exit 3")

      expect(status.exitstatus).to(eq(3))
      expect(metrics).to(have_received(:increment)
        .with("nexus.shell.executions", tags: ["command:sh", "outcome:failure"]))
    end

    it "tags a signal-terminated child as outcome:signaled" do
      _stdout, _stderr, status = shell.capture3("sh", "-c", "kill -9 $$")

      expect(status.signaled?).to(be(true))
      expect(status.termsig).to(eq(9))
      expect(metrics).to(have_received(:increment)
        .with("nexus.shell.executions", tags: ["command:sh", "outcome:signaled"]))
    end

    it "records metrics with outcome:exception and re-raises when the binary is missing" do
      expect { shell.capture3("definitely-not-a-real-binary-xyz") }.to(raise_error(Errno::ENOENT))

      expect(metrics).to(have_received(:increment)
        .with("nexus.shell.executions", tags: ["command:definitely-not-a-real-binary-xyz", "outcome:exception"]))
    end

    it "reports the child's peak RSS" do
      skip("requires procfs") unless File.exist?("/proc/self/status")

      # Allocate ~50 MB in the child, and keep it alive long enough to be sampled.
      shell.capture3(RbConfig.ruby, "-e", 'a = "x" * 50_000_000; sleep 0.3; a.length')

      expect(metrics).to(have_received(:distribution)
        .with("nexus.shell.peak_rss_mb", (be >= 50), tags: ["command:ruby", "outcome:success"]))
    end

    it "excludes a leading env hash from the logged command" do
      stdout, _stderr, _status = shell.capture3({ "SECRET_VALUE" => "hunter2" }, "sh", "-c", "echo $SECRET_VALUE")

      expect(stdout).to(eq("hunter2\n"))
      expect(shell.logger).to(have_received(:info)
        .with("Shell command finished.", hash_including(command: "sh -c echo $SECRET_VALUE")))
    end
  end
end
