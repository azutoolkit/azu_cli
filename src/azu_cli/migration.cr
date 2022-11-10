module AzuCLI
  class Migration
    include Command
    ARGS        = "-r Users -m post"
    OUTPUT_DIR  = "./"
    DESCRIPTION = <<-DESC
    #{bold "Azu - Scaffold"} - Generates a migration for your application
    
    DESC

    option resource : String, "--resource=Name", "-r Resource", "Resource name Eg. Articles", ""
    option fields : String, "--fields=name:type", "-f name:type", "A list of fields Eg. title:string text:text? author:reference", ""

    def run
      announce "Generating Migration: #{resource.camelcase} "
      validate

      model_args = [resource.camelcase]
      fields_list = fields.split(" ")
      fields_list.each do |f|
        model_args << f
      end

      announce "Generating Migration for resource: #{resource.camelcase} "
      Jennifer::Generators::Migration.new(model_args).render

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
  end
end
