require "./generators/**"

module AzuCLI
  class Project
    include Command

    ARGS        = "[name]"
    DESCRIPTION = <<-DESC
    #{bold "Azu - Project Generator"}

      The `azu project` command generates a new Crystal application with Azu
      installed and ORM.

      Docs - https://azutopia.gitbook.io/azu/installation
    DESC

    option db : String, "-db=postgres", "Generates project with Orm", "postgres"

    def run
      project = args.first.underscore

      announce "Creating Azu Project!"
      generator = Generator::Project.new project, db
      `mkdir -p ./#{project}`

      generator.render "./#{project}", interactive: true, list: true, color: true

      Dir.cd("./#{project}")

      announce "Installing shards and building CLI!"
      `shards install`

      announce "Formatting code"
      `crystal tool format`
      puts "\n\nDone generating #{underline project.capitalize} project"
      puts <<-TEXT
        #{light_blue "→"} cd ./#{project}
        #{light_blue "→"} run source .env to load environment variables
        #{light_blue "→"} run #{"azu dev".colorize(:green)} to start the server
      TEXT

      exit EXIT_SUCCESS
    end
  end
end
