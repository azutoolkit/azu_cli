require "log"
require "cadmium_inflector"
require "teeplate"
require "topia"

require "./azu_cli/dot_env"
require "./azu_cli/config"
require "./azu_cli/config/**"
require "./azu_cli/logger"
require "./azu_cli/utils"
require "./azu_cli/scratch_file"
require "./azu_cli/openapi"
require "./azu_cli/generators/**"
require "./azu_cli/commands/base"
require "./azu_cli/commands/database"
require "./azu_cli/commands/db/**"
require "./azu_cli/commands/jobs"
require "./azu_cli/commands/jobs/**"
require "./azu_cli/commands/session/**"
require "./azu_cli/commands/openapi/**"
require "./azu_cli/commands/**"
require "./azu_cli/cli"
require "./azu_cli/plugins/**"
require "./azu_cli/middleware/**"
require "./azu_cli/validators/**"

module AzuCLI
  # The shard version, read from shard.yml when the CLI is compiled.
  VERSION = {{ read_file("#{__DIR__}/../shard.yml").lines.find(&.starts_with?("version:")).split(":")[1].strip }}

  # Commands that run outside a project (or print only), so the working directory's `.env` is none of their business.
  COMMANDS_WITHOUT_DOT_ENV = %w[new init help version completion --help -h --version -v]

  # The environment a command runs in, for choosing `.env.<env>`: `test` for the test command, otherwise the
  # command's own `--env` / `-e` flag (a flag beats the shell), otherwise nil (CRYSTAL_ENV, then development).
  def self.command_environment(args : Array(String)) : String?
    return "test" if {"test", "t"}.includes?(args.first?)

    args.each_with_index do |arg, index|
      return nil if arg == "--" # what follows belongs to the program being run
      return args[index + 1]?.try { |value| value.starts_with?("-") ? nil : value } if arg == "--env" || arg == "-e"
      return arg.lchop("--env=") if arg.starts_with?("--env=")
    end
    nil
  end

  # Loads the project's `.env` files into the process environment, so database commands, the server, the
  # test runner and the programs they start see DATABASE_URL, the secrets and the rest. Variables the shell
  # already exported win. `azu serve --env production` and `azu db:migrate --env test` load `.env.production` /
  # `.env.test` (the flag sets CRYSTAL_ENV first), and `azu test` always runs as `test`, so a command never
  # hands its child a database URL of another environment. Returns the names it set (never the values).
  def self.load_project_env(args : Array(String), dir : String = ".") : Array(String)
    return [] of String if args.empty? || COMMANDS_WITHOUT_DOT_ENV.includes?(args.first)

    if environment = command_environment(args).try(&.presence)
      ENV["CRYSTAL_ENV"] = environment.downcase
    end
    warn_about_inherited_database_url(args)
    DotEnv.load_all(dir)
  end

  # `azu test` loads .env.test, but a DATABASE_URL already in the process wins over it.
  private def self.warn_about_inherited_database_url(args : Array(String)) : Nil
    return unless {"test", "t"}.includes?(args.first?) && ENV["DATABASE_URL"]?.presence

    DotEnv.warning_io.puts "warning: DATABASE_URL is set in your environment and wins over .env.test: the specs will use it"
  end

  # Main CLI entry point using Topia
  def self.run
    # The environment first: the configuration below reads AZU_ENV, DATABASE_URL and friends
    load_project_env(ARGV)

    # Initialize configuration and logging
    Config.load!
    Logger.setup

    # Create and run the CLI
    cli = CLI.new
    code = cli.run(ARGV)
    exit(code) unless code.zero?
  rescue ex : DotEnv::ParseError
    STDERR.puts "Invalid .env file: #{ex.message}" # the logger is not set up yet when the files load
    exit(Config::EXIT_FAILURE)
  rescue ex : Topia::Error
    Logger.error("Topia error: #{ex.message}")
    Logger.info("Run 'azu --help' to see available options")
    exit(Config::EXIT_INVALID_USAGE)
  rescue ex : Exception
    Logger.error("Critical error: #{ex.message}")
    Logger.debug("Stack trace: #{ex.backtrace?.try(&.join("\n")) || "No backtrace"}")
    exit(Config::EXIT_FAILURE)
  end
end

AzuCLI.run
