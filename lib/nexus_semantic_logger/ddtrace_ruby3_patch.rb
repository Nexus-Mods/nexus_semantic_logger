# frozen_string_literal: true
require 'ddtrace'

# Temporary monkey patch for ddtrace 1.9 in ruby 3.2.
# Supposedly fixed in upstream 1.10, once that is released.
# See https://github.com/DataDog/dd-trace-rb/issues/2534
Datadog::Core::Environment::VMCache.class_eval do
  module_function

  # Ruby >= 3.2 uses :constant_cache_invalidations instead of :global_constant_state
  # This is a temporary workaround, the correct solution is to report both :constant_cache_invalidations and
  # :constant_cache_misses in DD
  # See https://github.com/ruby/ruby/pull/5433,
  #     https://github.com/DataDog/dd-trace-rb/blob/v1.5.0/lib/datadog/core/environment/vm_cache.rb#L23-L25
  def global_constant_state
    RubyVM.stat[:constant_cache_invalidations]
  end
end
