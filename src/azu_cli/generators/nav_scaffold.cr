class Generator::NavScaffold < Teeplate::FileTree
  directory "#{__DIR__}/../templates/scaffold/public/templates/helpers"

  def initialize(@project : String, @resource : String)
  end
end
