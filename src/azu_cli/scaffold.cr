module AzuCLI
  class Scaffold
    include Command
    ARGS        = "-r Users -m post"
    OUTPUT_DIR  = "./"
    DESCRIPTION = <<-DESC
    #{bold "Azu - Scaffold"} - Generates resources your application

    Scaffolding is a quick way to generate some of the major pieces of an application. 
    If you want to create the models, pages, and endpoints for a new resource 
    in a single operation, scaffolding is the tool for the job.
    
    DESC

    option resource : String, "--resource=Name", "-r Resource", "Resource name Eg. Articles", ""
    option fields : String, "--fields=name:type", "-f name:type", "A list of fields Eg. title:string text:text? author:reference", ""

    def run
      announce "Scaffolding resource: #{resource.camelcase} "
      validate

      fields_list = fields.split(" ")
      args = [resource.camelcase] + fields_list

      scaffold fields_list

      announce "Generating Migration and Model for resource: #{resource.camelcase} "
      Jennifer::Generators::Model.new(args).render

      exit 1
    end

    private def validate
      errors = [] of String
      errors << "Missing option: resource" if resource.empty?
      errors << "Missing option: action" if fields.empty?

      return if errors.empty?
      error errors.join("\n")
      exit 1
    end

    private def scaffold(fields_list)
      nav = Generator::NavScaffold.new(project_name, resource.downcase)
      nav.render "./public/templates/helpers/", interactive: true, list: true, color: true

      generator = Generator::SrcScaffold.new(project_name, resource.downcase, fields_list)
      generator.render "./src", interactive: true, list: true, color: true

      pages = Generator::PagesScaffold.new(project_name, resource.downcase, fields_list)
      pages.render "./public/templates/pages", interactive: true, list: true, color: true
    end
  end
end
