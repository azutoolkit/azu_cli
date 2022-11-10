class Generator::PagesScaffold < Teeplate::FileTree
  directory "#{__DIR__}/../templates/scaffold/public/templates/pages"

  ACTIONS_PATH = {
    "index"   => "/:resource",
    "new"     => "/:resource/new",
    "create"  => "/:resource",
    "show"    => "/:resource/:id",
    "edit"    => "/:resource/:id/edit",
    "update"  => "/:resource/:id",
    "destroy" => "/:resource/:id",
  }

  getter fields : Jennifer::Generators::FieldSet

  def initialize(@project : String, @resource : String, @field_list : Array(String))
    @fields = Jennifer::Generators::FieldSet.new(@field_list)
  end

  private def path(action : Symbol)
    ACTIONS_PATH[action.to_s].gsub(":resource", @resource.pluralize)
  end
end
