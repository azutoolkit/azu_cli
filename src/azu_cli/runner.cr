module AzuCLI
  class Runner
    include Builder

    DESCRIPTION = <<-EOF
    Azu - Command Line Interface 

      AZU is a toolkit for artisans with expressive, elegant syntax that 
      offers great performance to build rich, interactive type safe, applications 
      quickly, with less code and conhesive parts that adapts to your prefer style.
    
      Clear ORM
    
      Clear is an ORM (Object Relation Mapping) built for Crystal language.
      
      Clear is built especially for PostgreSQL, meaning it's not compatible with
      MariaDB or SQLite for example. Therefore, it achieves to delivers a 
      tremendous amount of PostgreSQL advanced features out of the box.

    Documentation: 

      Azu       - https://azutopia.gitbook.io/azu/
      Clear ORM - https://clear.gitbook.io/project/

    Usage:

      - azu project name --clear
      - azu clear.model name -column:psqltype column:psqltype

    Subcommands:
    
      project   - Generates a new Azu project
      db        - Manages database versions and schema
      dev       - Starts server, watches for file changes and recompiles 
                  your project in the background

      Generators 

      channel   - Generates an Azu::Channel to handle websocket connections
      component - Generates an Azu::Component for building real time apps
      endpoint  - Generates an Azu::Endpoint for handling http resources
      request   - Generates an Azu::Request for validating and parsing http requests
      response  - Generates an Azu::Response that renders html response body 
      template  - Generates a Crinja Template for building and rendering HTML
      migration - Generates a Clear ORM Migration to change Postgres databases
      model     - Generates a Clear ORM Model and Migration
    
      Note: Must define DATABSE_URL env variable for Clear ORM commands to work
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
