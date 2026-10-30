require "./base"
require "../mcp_bridge"

module AzuCLI::Commands
  # MCP protocol belongs to the independently released native azu-mcp binary.
  # This command never loads a project's .env before handing off stdio.
  class MCP < Base
    def initialize
      super("mcp", "Configure or run the native Azu Toolkit MCP server")
    end

    def machine_output? : Bool
      true
    end

    def execute : Result
      arguments = all_args.dup
      action = arguments.shift? || "serve"
      case action
      when "bridge"
        MCPBridge.run(arguments, stdout)
        success
      when "setup"
        binary = ENV["AZU_MCP_BINARY"]? || "azu-mcp"
        config = arguments.first? || File.join(Path.home.to_s, ".config/azu-mcp/config.yml")
        stdout.puts({mcpServers: {azu: {command: binary, args: ["serve", "--config", config]}}}.to_pretty_json)
        success
      when "serve", "check", "approve", "approve-remote"
        binary = ENV["AZU_MCP_BINARY"]? || "azu-mcp"
        status = Process.run(binary, [action] + arguments, input: STDIN, output: stdout, error: STDERR)
        status.success? ? success : Result.error("azu-mcp exited with #{status.exit_code}", status.exit_code)
      when "--help", "help"
        stdout.puts "azu mcp setup [CONFIG] | serve --config CONFIG | check --config CONFIG | approve PLAN --config CONFIG\nInstall the native azu-mcp binary separately. Setup prints configuration; it does not overwrite editor settings."
        success
      else
        usage_error("Unknown MCP command; use azu mcp --help")
      end
    rescue ex
      Result.error(ex.message || "MCP failed")
    end
  end
end
