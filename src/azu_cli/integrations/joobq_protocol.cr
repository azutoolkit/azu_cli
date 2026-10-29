# Compiled inside the application, never linked into the CLI. Custom history-store
# adapters implement this boundary without importing terminal rendering code.
require "json"

module AzuJoobQDashboard
  abstract class Provider
    abstract def snapshot : JSON::Any
    abstract def replay(id : String) : JSON::Any
  end

  class_property provider : Provider?
end
