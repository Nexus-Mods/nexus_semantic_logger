# frozen_string_literal: true

require "rails_helper"
require "nexus_semantic_logger"

RSpec.describe(NexusSemanticLogger::Application) do
  describe "rails_semantic_logger compatibility warning" do
    def warn_on_incompatible
      described_class.send(:warn_on_incompatible_rails_semantic_logger)
    end

    it "warns when RuntimeRegistry lacks sql_runtime on rails_semantic_logger 4.x" do
      stub_const("ActiveRecord::RuntimeRegistry", Module.new)
      stub_const("RailsSemanticLogger::VERSION", "4.17.0")

      expect(described_class.logger).to(receive(:warn).with(/rails_semantic_logger", ">= 5.1"/))

      warn_on_incompatible
    end

    it "stays quiet when sql_runtime is available" do
      registry = Module.new do
        def self.sql_runtime
          0.0
        end
      end
      stub_const("ActiveRecord::RuntimeRegistry", registry)
      stub_const("RailsSemanticLogger::VERSION", "4.17.0")

      expect(described_class.logger).not_to(receive(:warn))

      warn_on_incompatible
    end

    it "stays quiet on rails_semantic_logger 5.x" do
      stub_const("ActiveRecord::RuntimeRegistry", Module.new)
      stub_const("RailsSemanticLogger::VERSION", "5.1.0")

      expect(described_class.logger).not_to(receive(:warn))

      warn_on_incompatible
    end

    it "stays quiet when ActiveRecord is not loaded" do
      hide_const("ActiveRecord::RuntimeRegistry")

      expect(described_class.logger).not_to(receive(:warn))

      warn_on_incompatible
    end
  end
end
