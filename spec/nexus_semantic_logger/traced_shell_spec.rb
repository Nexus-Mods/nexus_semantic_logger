# frozen_string_literal: true

require "spec_helper"
require "nexus_semantic_logger"
require "tempfile"

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
        .with("nexus.shell.peak_rss_mb", be >= 50, tags: ["command:ruby", "outcome:success"]))
    end

    # Temporal cancels an activity by raising into its thread. Before this the raise unwound into
    # popen3's ensure, which waited for the child: a 7z nobody wanted any more ran on for hours,
    # holding memory and an activity slot (OBX-706).
    context "when the caller's thread is interrupted" do
      let(:cancelled) { Class.new(StandardError) }
      let(:pidfile) { Tempfile.new("traced-shell-grandchild") }

      after { pidfile.close! }

      def wait_for(timeout: 5)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
        until (value = yield)
          raise "timed out waiting" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

          sleep(0.02)
        end
        value
      end

      # A zombie answers kill(0) until it is reaped, which under a PID 1 with no reaper is never.
      def gone?(pid)
        Process.kill(0, pid)
        File.read("/proc/#{pid}/status").match?(/^State:\s+Z/)
      rescue Errno::ESRCH, Errno::ENOENT
        true
      end

      # sh (the child) backgrounds sleep (a grandchild), records its pid so the spec knows the
      # command is running, then waits on it.
      let(:cmd) { ["sh", "-c", "sleep 30 & echo $! > #{pidfile.path}; wait"] }

      # The cancellation is asserted on #value; without this Ruby also prints it to stderr.
      def run_in_thread
        Thread.new { shell.capture3(*cmd) }.tap { |t| t.report_on_exception = false }
      end

      def grandchild_pid
        wait_for { File.read(pidfile.path).strip.then { |text| text.empty? ? nil : Integer(text) } }
      end

      it "kills the child and its descendants instead of waiting for them" do
        calling_thread = run_in_thread
        grandchild = grandchild_pid

        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        calling_thread.raise(cancelled, "activity cancelled")

        expect { calling_thread.value }.to(raise_error(cancelled))
        expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to(be < described_class::KILL_GRACE_SECONDS)
        expect(wait_for { gone?(grandchild) }).to(be(true))
      end

      it "still records the run as an exception" do
        calling_thread = run_in_thread
        grandchild_pid
        calling_thread.raise(cancelled, "activity cancelled")
        expect { calling_thread.value }.to(raise_error(cancelled))

        expect(metrics).to(have_received(:increment)
          .with("nexus.shell.executions", tags: ["command:sh", "outcome:exception"]))
      end
    end

    it "excludes a leading env hash from the logged command" do
      stdout, _stderr, _status = shell.capture3({ "SECRET_VALUE" => "hunter2" }, "sh", "-c", "echo $SECRET_VALUE")

      expect(stdout).to(eq("hunter2\n"))
      expect(shell.logger).to(have_received(:info)
        .with("Shell command finished.", hash_including(command: "sh -c echo $SECRET_VALUE")))
    end
  end
end
