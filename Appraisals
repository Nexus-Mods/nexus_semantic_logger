# frozen_string_literal: true

appraise "rails-7-1" do
  gem "railties", "~> 7.1.0"
end

appraise "rails-7-2" do
  gem "railties", "~> 7.2.0"
end

appraise "rails-8-0" do
  gem "railties", "~> 8.0.0"
  # Matrix spread: 4.17 on rails 7.1 and 7.2, 5.0 here, 5.1 on rails 8.1.
  gem "rails_semantic_logger", "~> 5.0.0"
end

appraise "rails-8-1" do
  gem "railties", "~> 8.1.0"
  # No 4.x release works on Rails 8.1.
  gem "rails_semantic_logger", "~> 5.1"
end
