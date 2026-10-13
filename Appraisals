# frozen_string_literal: true

appraise "rails-7-1" do
  gem "railties", "~> 7.1.0"
  # json 3.0 (2026-09-07) rejects the quirks_mode option that ActiveSupport's JSON encoder passed
  # until Rails 7.2.4 / 8.1.4. The 7.1 and 8.0 lines will not get that fix, so hold json at 2.x
  # for them or every to_json call raises ArgumentError. Dev/test only - the gemspec is untouched.
  gem "json", "< 3"
end

appraise "rails-7-2" do
  gem "railties", "~> 7.2.0"
end

appraise "rails-8-0" do
  gem "railties", "~> 8.0.0"
  # json 3.0 (2026-09-07) rejects the quirks_mode option that ActiveSupport's JSON encoder passed
  # until Rails 7.2.4 / 8.1.4. The 7.1 and 8.0 lines will not get that fix, so hold json at 2.x
  # for them or every to_json call raises ArgumentError. Dev/test only - the gemspec is untouched.
  gem "json", "< 3"
end

appraise "rails-8-1" do
  gem "railties", "~> 8.1.0"
  # No 4.x release of rails_semantic_logger works on Rails 8.1, and bundler will not upgrade past
  # 4.x on its own when an older lockfile exists.
  gem "rails_semantic_logger", "~> 5.1"
end
