# frozen_string_literal: true

# noinspection RubyClassVariableUsageInspection
class ResponseCodeStatsMiddleware
  def initialize(app)
    @app = app
    @@code_metrics = {}
  end

  def call(env)
    status, headers, response = @app.call(env)

    @@code_metrics[status] ||= 0
    @@code_metrics[status] += 1

    [status, headers, response]
  end

  def self.read_and_reset_metrics
    metrics = @@code_metrics.dup
    @@code_metrics.clear
    metrics
  end
end
