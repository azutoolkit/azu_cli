module AzuCLI
  class Help
    include Builder

    DESCRIPTION = <<-EOF
    #{bold "AZU Toolkit"} - Command Line Interface

      AZU is a toolkit for artisans with expressive, elegant syntax that 
      offers great performance to build rich, interactive type safe, 
      applications quickly, with less code and conhesive parts that adapts 
      to your prefer style.

      #{underline :Documentation} 

      - Azu       - https://azutopia.gitbook.io/azu/
      - Clear ORM - https://clear.gitbook.io/project/

      #{underline :Examples}

      #{light_blue :azu} project name --clear
      #{light_blue :azu} model -n User -props first_name:varchar email:varchar

      #{underline "Subcommands"}

      #{light_blue :project}    - Generates a new Azu project
      #{light_blue :dev}        - Recompiles on crystal file changes
      #{light_blue :db}         - Manages database versions and schema
      #{light_blue :model}      - Generates a Clear ORM Model and Migration
      #{light_blue :endpoint}   - Generates an Azu::Endpoint for handling http resources
      #{light_blue :component}  - Generates an Azu::Component for building real time apps
      #{light_blue :channel}    - Generates an Azu::Channel to handle websocket connections
      #{light_blue :response}   - Generates an Azu::Response that renders html response body 
      #{light_blue :migration}  - Generates a Clear ORM Migration to change Postgres databases
      #{light_blue :request}    - Generates an Azu::Request for validating and parsing http requests
    
      #{underline "Note"}
    
      - Must define DATABSE_URL env variable for Clear ORM commands to work
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
