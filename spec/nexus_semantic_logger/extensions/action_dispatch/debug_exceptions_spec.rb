# frozen_string_literal: true

require "rails_helper"

# Require after the real middleware (loaded by rails_helper) so the original
# ActionDispatch::DebugExceptions#log_error exists for the patch's `undef_method` to remove.
require "nexus_semantic_logger/extensions/action_dispatch/debug_exceptions"

RSpec.describe(ActionDispatch::DebugExceptions) do
  subject(:middleware) { described_class.new(->(_env) { [200, {}, []] }) }

  let(:exception) { RuntimeError.new("boom") }
  let(:wrapper) { ActionDispatch::ExceptionWrapper.new(nil, exception) }
  let(:request) { ActionDispatch::Request.new({}) }
  let(:logger) { instance_double(SemanticLogger::Logger) }

  before { allow(ActionController::Base).to(receive(:logger).and_return(logger)) }

  describe "#log_error" do
    # Regression: on Rails 7.2 the singleton ActiveSupport::Deprecation.silence was removed. The previous
    # implementation called it unconditionally, raising NoMethodError inside render_exception before the
    # exception could be logged - so exceptions surfaced as empty 500s with no backtrace.
    it "logs the exception at fatal level without raising" do
      expect(logger).to(receive(:fatal).with(wrapper.exception))

      expect { middleware.send(:log_error, request, wrapper) }.not_to(raise_error)
    end

    it "silences deprecations via the API available on the running Rails version" do
      allow(logger).to(receive(:fatal))

      if (Rails::VERSION::MAJOR == 7 && Rails::VERSION::MINOR >= 1) || Rails::VERSION::MAJOR > 7
        expect(Rails.application.deprecators).to(receive(:silence).and_yield)
      else
        expect(ActiveSupport::Deprecation).to(receive(:silence).and_yield)
      end

      middleware.send(:log_error, request, wrapper)
    end
  end
end
