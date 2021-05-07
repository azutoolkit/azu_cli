module AzuCLI
  class Azu
    include Topia::Plugin
    include Helpers
    include Base
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

    Sub-commands:
    
      project   - Generates a new Azu project
      db        - Manages database versions
      dev       - Starts server, watches for file changes and recompiles 
                  your project in the background
      component - Generates an Azu::Component
      endpoint  - Generate an Azu::Endpoint
      request   - Generate an Azu::Request
      response  - Generate an Azu::Response
      template  - Generate a Crinja Template
      channel   - Generate a Crinja Template

      clear.migrator  - Performs database maintenance tasks
      clear.migration - Generates a Clear ORM Migration
      clear.model     - Generates a Clear ORM Model and Migration
    
      Note: Must define DATABSE_URL env variable for Clear ORM commands to work
    EOF

    def run
      puts "hello"
    rescue
      error("Build failed!")
    end

    def on(event : String)
    end
  end
end
