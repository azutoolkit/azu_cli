require "spec"
require "log"
require "cadmium_inflector"
require "teeplate"
require "topia"

# Set test environment BEFORE loading any AzuCLI code
ENV["AZU_ENV"] = "test"
ENV["AZU_QUIET"] = "true"

# Load test helpers
require "./support/test_helpers"

# Load only the specific modules we need for testing
require "../src/azu_cli"
require "../src/azu_cli/commands/base"
require "../src/azu_cli/commands/database"
require "../src/azu_cli/commands/db/**"
require "../src/azu_cli/commands/jobs"
require "../src/azu_cli/commands/jobs/**"
require "../src/azu_cli/commands/openapi/**"
require "../src/azu_cli/validators/**"
require "../src/azu_cli/middleware/**"
require "../src/azu_cli/plugins/**"

# Load specific commands that don't depend on generators
require "../src/azu_cli/commands/help"
require "../src/azu_cli/commands/init"
require "../src/azu_cli/commands/new"
require "../src/azu_cli/commands/serve"
require "../src/azu_cli/commands/version"
require "../src/azu_cli/commands/test"

# Configure test environment after loading modules
Spec.before_suite do
  # Ensure test mode is active
  AzuCLI::Config.instance.quiet = true
  AzuCLI::Config.instance.colored_output = false
  AzuCLI::Config.instance.log_level = Log::Severity::Error

  # Configure Crystal's logging to suppress output during tests
  Log.setup do |c|
    c.bind "*", Log::Severity::Error, Log::IOBackend.new(io: IO::Memory.new)
  end
end
