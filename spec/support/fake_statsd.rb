# frozen_string_literal: true

# Stands in for Datadog::Statsd, a network client, and records calls so specs
# can assert on emitted metrics as plain data.
class FakeStatsd
  attr_reader :calls

  def initialize
    @calls = []
  end

  %i[increment decrement count gauge distribution timing].each do |name|
    define_method(name) do |*args, **kwargs|
      @calls << [name, *args, kwargs]
    end
  end

  def flush(sync: false)
    @calls << [:flush, { sync: sync }]
  end
end
