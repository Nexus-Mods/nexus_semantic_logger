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
      return if !log_rescued_responses?(request) && wrapper.rescue_response?

      ActiveSupport::Deprecation.silence do
        ActionController::Base.logger.fatal(wrapper.exception)
      end
    end
  end
end
