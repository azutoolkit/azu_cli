module AzuCLI
  class Help
    include Command

    DESCRIPTION = <<-EOF
    #{bold "AZU Toolkit"} - Command Line Interface

      AZU is a toolkit for artisans with expressive, elegant syntax that 
      offers great performance to build rich, interactive type safe, 
      applications quickly, with less code and conhesive parts that adapts 
      to your prefer style.

      #{underline :Documentation} 

      - Azu - https://azutopia.gitbook.io/azu/
      - ORM - https://imdrasil.github.io/jennifer.cr/docs/

      #{underline :Examples}

      #{light_blue :azu} project name -db postgres

      #{underline "Subcommands"}

      #{light_blue :project}    - Generates a new Azu project
      #{light_blue :task}       - Generates a task definition file
      #{light_blue :scaffold}   - Generates a resource for your application
      #{light_blue :dev}        - Recompiles on crystal file changes
      #{light_blue :db}         - Manages database versions and schema
    EOF

    def self.run
      new.run
    end

    def run
      return Topia.run("azu", ["--help"]) if ARGV.empty?
      return Topia.run("azu", ARGV) if ["--help", "--version"].includes?(ARGV.first)
      task, command = ARGV.first, ARGV[1..-1]
      Topia.run(task, command)
    end
  end
end
