require "./base"

module AzuCLI
  module Commands
    # Shell completion script generator
    class Completion < Base
      property shell : String? = nil

      # All available commands for completion
      COMMANDS = %w[
        new init generate g serve server s test t help version
        db:create db:drop db:migrate db:rollback db:seed db:reset db:status db:setup
        jobs:worker jobs:status jobs:clear jobs:retry jobs:ui
        session:setup session:clear
        openapi:generate openapi:export
        config:show config:validate config:env
        plugin completion
      ]

      # Generator types
      GENERATORS = %w[
        endpoint model service middleware request page component
        migration scaffold auth channel mailer job joobq
      ]

      def initialize
        super("completion", "Generate shell completion scripts")
      end

      def execute : Result
        parse_options

        shell_type = @shell || detect_shell

        unless shell_type
          show_help
          return error("Could not detect shell. Please specify with --shell")
        end

        case shell_type.downcase
        when "bash"
          puts generate_bash_completion
        when "zsh"
          puts generate_zsh_completion
        when "fish"
          puts generate_fish_completion
        else
          return error("Unsupported shell: #{shell_type}. Supported: bash, zsh, fish")
        end

        success("Completion script generated for #{shell_type}")
      end

      private def parse_options
        args = get_args
        args.each_with_index do |arg, index|
          case arg
          when "--shell", "-s"
            @shell = args[index + 1]? if index + 1 < args.size
          when "bash", "zsh", "fish"
            @shell = arg
          when "--help", "-h"
            show_help
            exit(0)
          end
        end
      end

      private def detect_shell : String?
        ENV["SHELL"]?.try do |shell|
          case shell
          when /bash/ then "bash"
          when /zsh/  then "zsh"
          when /fish/ then "fish"
          else             nil
          end
        end
      end

      private def generate_bash_completion : String
        <<-BASH
        # Azu CLI Bash Completion
        # Add to ~/.bashrc or ~/.bash_profile:
        # eval "$(azu completion bash)"

        _azu_completions() {
            local cur prev opts
            COMPREPLY=()
            cur="${COMP_WORDS[COMP_CWORD]}"
            prev="${COMP_WORDS[COMP_CWORD-1]}"

            # Top-level commands
            local commands="#{COMMANDS.join(" ")}"

            # Generator types
            local generators="#{GENERATORS.join(" ")}"

            case "${prev}" in
                azu)
                    COMPREPLY=( $(compgen -W "${commands}" -- ${cur}) )
                    return 0
                    ;;
                generate|g)
                    COMPREPLY=( $(compgen -W "${generators}" -- ${cur}) )
                    return 0
                    ;;
                --shell|-s)
                    COMPREPLY=( $(compgen -W "bash zsh fish" -- ${cur}) )
                    return 0
                    ;;
                --format|-f)
                    COMPREPLY=( $(compgen -W "yaml json table" -- ${cur}) )
                    return 0
                    ;;
                --env|-e)
                    COMPREPLY=( $(compgen -W "development test production" -- ${cur}) )
                    return 0
                    ;;
                --db)
                    COMPREPLY=( $(compgen -W "postgresql mysql sqlite" -- ${cur}) )
                    return 0
                    ;;
                --type)
                    COMPREPLY=( $(compgen -W "web api cli" -- ${cur}) )
                    return 0
                    ;;
                *)
                    if [[ ${cur} == -* ]]; then
                        COMPREPLY=( $(compgen -W "--help --verbose --quiet --force" -- ${cur}) )
                    fi
                    return 0
                    ;;
            esac
        }

        complete -F _azu_completions azu
        BASH
      end

      private def generate_zsh_completion : String
        <<-ZSH
        #compdef azu
        # Azu CLI Zsh Completion
        # Add to ~/.zshrc:
        # eval "$(azu completion zsh)"

        _azu() {
            local -a commands generators

            commands=(
                #{COMMANDS.map { |c| "'#{c}:#{command_description(c)}'" }.join("\n                ")}
            )

            generators=(
                #{GENERATORS.map { |g| "'#{g}:Generate #{g}'" }.join("\n                ")}
            )

            _arguments -C \\
                '1:command:->command' \\
                '*::arg:->args'

            case $state in
                command)
                    _describe 'command' commands
                    ;;
                args)
                    case ${words[1]} in
                        generate|g)
                            _describe 'generator' generators
                            ;;
                        *)
                            _files
                            ;;
                    esac
                    ;;
            esac
        }

        compdef _azu azu
        ZSH
      end

      private def generate_fish_completion : String
        commands_str = COMMANDS.map { |c|
          "complete -c azu -n '__fish_use_subcommand' -a '#{c}' -d '#{command_description(c)}'"
        }.join("\n")

        generators_str = GENERATORS.map { |g|
          "complete -c azu -n '__fish_seen_subcommand_from generate g' -a '#{g}' -d 'Generate #{g}'"
        }.join("\n")

        <<-FISH
        # Azu CLI Fish Completion
        # Add to ~/.config/fish/completions/azu.fish

        # Disable file completion for azu
        complete -c azu -f

        # Commands
        #{commands_str}

        # Generators
        #{generators_str}

        # Common options
        complete -c azu -l help -s h -d 'Show help'
        complete -c azu -l verbose -d 'Verbose output'
        complete -c azu -l quiet -d 'Quiet mode'
        complete -c azu -l force -d 'Force operation'

        # New command options
        complete -c azu -n '__fish_seen_subcommand_from new' -l type -d 'Project type' -xa 'web api cli'
        complete -c azu -n '__fish_seen_subcommand_from new' -l db -d 'Database' -xa 'postgresql mysql sqlite'
        complete -c azu -n '__fish_seen_subcommand_from new' -l no-git -d 'Skip git initialization'
        complete -c azu -n '__fish_seen_subcommand_from new' -l no-docker -d 'Skip docker support'
        complete -c azu -n '__fish_seen_subcommand_from new' -l yes -d 'Non-interactive mode'

        # Config command options
        complete -c azu -n '__fish_seen_subcommand_from config:show' -l format -s f -d 'Output format' -xa 'yaml json table'
        complete -c azu -n '__fish_seen_subcommand_from config:show' -l section -s s -d 'Show section'
        complete -c azu -n '__fish_seen_subcommand_from config:validate' -l strict -d 'Strict validation'
        complete -c azu -n '__fish_seen_subcommand_from config:env' -l list -d 'List variables'
        complete -c azu -n '__fish_seen_subcommand_from config:env' -l show -d 'Show values'

        # Completion command options
        complete -c azu -n '__fish_seen_subcommand_from completion' -l shell -s s -d 'Shell type' -xa 'bash zsh fish'
        FISH
      end

      private def command_description(cmd : String) : String
        case cmd
        when "new"                  then "Create a new project"
        when "init"                 then "Initialize in existing project"
        when "generate", "g"        then "Generate code components"
        when "serve", "server", "s" then "Start development server"
        when "test", "t"            then "Run tests"
        when "help"                 then "Show help"
        when "version"              then "Show version"
        when "db:create"            then "Create database"
        when "db:drop"              then "Drop database"
        when "db:migrate"           then "Run migrations"
        when "db:rollback"          then "Rollback migrations"
        when "db:seed"              then "Seed database"
        when "db:reset"             then "Reset database"
        when "db:status"            then "Show migration status"
        when "db:setup"             then "Setup database"
        when "jobs:worker"          then "Start job worker"
        when "jobs:status"          then "Show job status"
        when "jobs:clear"           then "Clear jobs"
        when "jobs:retry"           then "Retry failed jobs"
        when "jobs:ui"              then "Start jobs UI"
        when "session:setup"        then "Setup sessions"
        when "session:clear"        then "Clear sessions"
        when "openapi:generate"     then "Generate from OpenAPI"
        when "openapi:export"       then "Export OpenAPI spec"
        when "config:show"          then "Show configuration"
        when "config:validate"      then "Validate configuration"
        when "config:env"           then "Manage environment"
        when "plugin"               then "Plugin management"
        when "completion"           then "Generate completions"
        else                             cmd
        end
      end

      def show_help
        puts "Usage: azu completion [shell]"
        puts ""
        puts "Generate shell completion scripts for Azu CLI."
        puts ""
        puts "Options:"
        puts "  --shell, -s SHELL   Shell type (bash, zsh, fish)"
        puts "  --help, -h          Show this help message"
        puts ""
        puts "Shells:"
        puts "  bash    Bash completion script"
        puts "  zsh     Zsh completion script"
        puts "  fish    Fish completion script"
        puts ""
        puts "Installation:"
        puts ""
        puts "  Bash (add to ~/.bashrc):"
        puts "    eval \"$(azu completion bash)\""
        puts ""
        puts "  Zsh (add to ~/.zshrc):"
        puts "    eval \"$(azu completion zsh)\""
        puts ""
        puts "  Fish (save to completions):"
        puts "    azu completion fish > ~/.config/fish/completions/azu.fish"
        puts ""
        puts "Examples:"
        puts "  azu completion bash"
        puts "  azu completion --shell zsh"
        puts "  azu completion fish > ~/.config/fish/completions/azu.fish"
      end
    end
  end
end
