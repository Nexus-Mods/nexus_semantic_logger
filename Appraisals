# frozen_string_literal: true

appraise "rails-7-1" do
  gem "railties", "~> 7.1.0"
end

appraise "rails-7-2" do
  gem "railties", "~> 7.2.0"
end

appraise "rails-8-0" do
  gem "railties", "~> 8.0.0"
end

appraise "rails-8-1" do
  gem "railties", "~> 8.1.0"
  # No 4.x release of rails_semantic_logger works on Rails 8.1, and bundler will not upgrade past
  # 4.x on its own when an older lockfile exists.
  gem "rails_semantic_logger", "~> 5.1"
end
