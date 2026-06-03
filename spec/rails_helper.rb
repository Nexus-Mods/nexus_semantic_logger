# frozen_string_literal: true

require "spec_helper"

require "rails"
require "action_controller/railtie"
require "action_dispatch/middleware/debug_exceptions"
require "semantic_logger"

# A minimal Rails application so Rails.application (and Rails.application.deprecators) exist for the
# extensions under test. Defining the subclass is enough to wire up Rails.application; no initialize! needed.
module Dummy
  class Application < Rails::Application
    config.eager_load = false
    config.secret_key_base = "test-secret-key-base"
  end
end
