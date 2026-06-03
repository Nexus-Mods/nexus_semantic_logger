# frozen_string_literal: true
# Log actual exceptions, not a string representation
require "action_dispatch"

module ActionDispatch
  # Fork of the rails_semantic_logger DebugExceptions to fix its removal of the upstream 'log_rescued_responses' check.
  # This allows applications to use the 'config.action_dispatch.log_rescued_responses' setting.
  class DebugExceptions
    private

    undef_method :log_error

    def log_error(request, wrapper)
      # log_rescued_responses? is a rails7 feature, but this gem is also used on rails6. Check for its existence.
      return if respond_to?('log_rescued_responses?') && !log_rescued_responses?(request) && wrapper.rescue_response?

      # Silence deprecations emitted while logging the exception. The API changed in Rails 7.1: the
      # ActiveSupport::Deprecation singleton was deprecated and its class-level `silence` was removed in 7.2,
      # replaced by Rails.application.deprecators. Calling the removed singleton on >= 7.2 raises NoMethodError
      # inside render_exception (before the exception is logged), which swallowed all exception logging and
      # produced empty 500s. Use whichever API the Rails version provides, mirroring rails_semantic_logger.
      if (Rails::VERSION::MAJOR == 7 && Rails::VERSION::MINOR >= 1) || Rails::VERSION::MAJOR > 7
        Rails.application.deprecators.silence do
          ActionController::Base.logger.fatal(wrapper.exception)
        end
      else
        ActiveSupport::Deprecation.silence do
          ActionController::Base.logger.fatal(wrapper.exception)
        end
      end
    end
  end
end
