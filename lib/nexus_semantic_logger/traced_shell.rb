# frozen_string_literal: true
require 'open3'
require 'semantic_logger'

module NexusSemanticLogger
  # Instrumented replacement for Open3.capture3, so child processes (7z, unrar, yara, ...) are
  # observable. Each call produces:
  #   - a Datadog APM span ('shell.exec', resource = binary basename) tagged with the command line,
  #     exit status, terminating signal and peak RSS
  #   - statsd metrics: nexus.shell.duration_ms (timing), nexus.shell.peak_rss_mb (distribution)
  #     and nexus.shell.executions (count), tagged with command:<binary> and
  #     outcome:<success|failure|signaled|exception>
  #   - an info log line with the same payload
  #
  # Peak RSS is the child's kernel-maintained high-water mark (VmHWM in /proc/<pid>/status),
  # sampled while the child runs. Linux only; nil elsewhere. Direct child only - grandchildren
  # are not measured. A process killed by the kernel OOM killer reports outcome:signaled with
  # termsig 9 and the last-sampled peak RSS, which is exactly the evidence an OOM postmortem needs.
  class TracedShell
    include SemanticLogger::Loggable

    SPAN_NAME = 'shell.exec'
    METRIC_PREFIX = 'nexus.shell'
    RSS_POLL_INTERVAL_SECONDS = 0.05
    COMMAND_LOG_MAX_CHARS = 500

    # Drop-in replacement for Open3.capture3.
    # A leading env Hash and trailing spawn options are supported as with Open3; the env Hash is
    # excluded from spans/logs since it may hold secrets.
    # @return [Array(String, String, Process::Status)] stdout, stderr, status.
    def capture3(*cmd, stdin_data: '', binmode: false, **opts)
      binary = command_basename(cmd)
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      outcome = 'exception'
      status = nil
      peak_rss_kb = nil
      trace(binary, cmd) do |span|
        stdout, stderr, status, peak_rss_kb = run_capture3(cmd, stdin_data, binmode, opts)
        outcome = outcome_for(status)
        annotate_span(span, status, peak_rss_kb)
        [stdout, stderr, status]
      end
    ensure
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
      record(binary, cmd, outcome, duration_ms, status, peak_rss_kb)
    end

    private

    def trace(binary, cmd, &block)
      return yield(nil) unless defined?(Datadog::Tracing)

      Datadog::Tracing.trace(SPAN_NAME, resource: binary, type: 'system') do |span|
        span.set_tag('shell.command', command_string(cmd))
        block.call(span)
      end
    end

    # Open3.capture3 semantics, reimplemented over popen3 so the child pid is available to the
    # RSS poller while it runs.
    def run_capture3(cmd, stdin_data, binmode, opts)
      Open3.popen3(*cmd, **opts) do |stdin, stdout, stderr, wait_thr|
        if binmode
          stdin.binmode
          stdout.binmode
          stderr.binmode
        end
        poller = start_rss_poller(wait_thr)
        out_reader = Thread.new { stdout.read }
        err_reader = Thread.new { stderr.read }
        begin
          stdin.write(stdin_data) if stdin_data && !stdin_data.empty?
        rescue Errno::EPIPE
          # Child exited without consuming stdin; Open3.capture3 ignores this too.
        end
        stdin.close
        status = wait_thr.value
        [out_reader.value, err_reader.value, status, poller&.value]
      end
    end

    def start_rss_poller(wait_thr)
      return nil unless procfs?

      pid = wait_thr.pid
      Thread.new do
        peak_kb = nil
        while wait_thr.alive?
          sample = read_vm_hwm_kb(pid)
          peak_kb = sample if sample && (peak_kb.nil? || sample > peak_kb)
          sleep(RSS_POLL_INTERVAL_SECONDS)
        end
        peak_kb
      end
    end

    # VmHWM is the process's peak RSS as maintained by the kernel, so each sample is itself a
    # high-water mark; the true peak can only be missed by the process exiting within one poll.
    def read_vm_hwm_kb(pid)
      File.read("/proc/#{pid}/status")[/^VmHWM:\s*(\d+)\s*kB/, 1]&.to_i
    rescue SystemCallError, IOError
      nil
    end

    def procfs?
      return @procfs if defined?(@procfs)

      @procfs = File.exist?('/proc/self/status')
    end

    def outcome_for(status)
      return 'success' if status.success?
      return 'signaled' if status.signaled?

      'failure'
    end

    def annotate_span(span, status, peak_rss_kb)
      return unless span

      span.set_tag('shell.exit_status', status.exitstatus) if status.exitstatus
      span.set_tag('shell.termsig', status.termsig) if status.signaled?
      span.set_tag('shell.peak_rss_mb', to_mb(peak_rss_kb)) if peak_rss_kb
    end

    def record(binary, cmd, outcome, duration_ms, status, peak_rss_kb)
      tags = ["command:#{binary}", "outcome:#{outcome}"]
      metrics = NexusSemanticLogger.metrics
      metrics.timing("#{METRIC_PREFIX}.duration_ms", duration_ms, tags: tags)
      metrics.increment("#{METRIC_PREFIX}.executions", tags: tags)
      peak_rss_mb = peak_rss_kb && to_mb(peak_rss_kb)
      metrics.distribution("#{METRIC_PREFIX}.peak_rss_mb", peak_rss_mb, tags: tags) if peak_rss_mb

      payload = {
        command: command_string(cmd),
        outcome: outcome,
        duration_ms: duration_ms,
        exit_status: status&.exitstatus,
        termsig: status&.signaled? ? status.termsig : nil,
        peak_rss_mb: peak_rss_mb,
      }.compact
      logger.info('Shell command finished.', payload)
    end

    # Binary basename for span resource and metric tags; deliberately low cardinality.
    def command_basename(cmd)
      first = cmd.first.is_a?(Hash) ? cmd[1] : cmd.first
      first = first.first if first.is_a?(Array) # [binary, argv0] form
      return 'unknown' unless first.is_a?(String)

      File.basename(first.split(' ').first.to_s)
    end

    def command_string(cmd)
      cmd.reject { |part| part.is_a?(Hash) }
         .flatten
         .join(' ')
         .slice(0, COMMAND_LOG_MAX_CHARS)
    end

    def to_mb(kb)
      kb.fdiv(1024).round(1)
    end
  end
end
