# frozen_string_literal: true

# json 3.0 (2026-09-07) rejects the quirks_mode option that ActiveSupport's JSON encoder used to
# pass to JSON.generate. Rails removed it on main before 8.1.0 (rails/rails#55534) and backported it
# to 7.2.4, but 7.1.6 and 8.0.5.1 - the latest on their lines - still pass it, so every to_json call
# raises ArgumentError once json 3 is resolved. Hold json at 2.x on those two lanes. Dev/test only,
# the gemspec is untouched. Drop the pin for 8.0 if a patch release ever ships with the backport.

appraise "rails-7-1" do
  gem "railties", "~> 7.1.0"
  gem "json", "< 3" # see the json 3 note at the top of this file
end

appraise "rails-7-2" do
  gem "railties", "~> 7.2.0"
end

appraise "rails-8-0" do
  gem "railties", "~> 8.0.0"
  gem "json", "< 3" # see the json 3 note at the top of this file
end

appraise "rails-8-1" do
  gem "railties", "~> 8.1.0"
  # No 4.x release of rails_semantic_logger works on Rails 8.1, and bundler will not upgrade past
  # 4.x on its own when an older lockfile exists.
  gem "rails_semantic_logger", "~> 5.1"
end
