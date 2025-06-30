module AzuCLI
  class Generator::Project < Teeplate::FileTree
    directory "#{__DIR__}/../templates/project"

    getter database_name

    @project : String
    @database : String
    @database_name : String
    @author : String
    @email : String
    @github_name : String

    def initialize(@project, @database = "pg")
      @database_name = generate_database_name
      @author = fetch_author
      @email = fetch_email
      @github_name = fetch_github_name
    end

    private def generate_database_name
      @project.gsub('-', '_')
    end

    def which_git_command
      system("which git >/dev/null")
    end

    def fetch_author
      if which_git_command
        user_name = `git config --get user.name`.strip
        user_name = nil if user_name.empty?
      end
      user_name || "your-name-here"
    end

    def fetch_email
      if which_git_command
        user_email = `git config --get user.email`.strip
        user_email = nil if user_email.empty?
      end
      user_email || "your-email-here"
    end

    def fetch_github_name
      if which_git_command
        github_user = `git config --get github.user`.strip
        github_user = nil if github_user.empty?
      end
      github_user || "your-github-user"
    end
  end
end
