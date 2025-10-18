module AzuCli::Post
  struct ShowEndpoint
    include Azu::Endpoint(Post::ShowRequest, Post::ShowPage)

    get "/posts/:id"

    def call : Post::ShowPage
      # TODO: Implement show action logic
      # Example usage:
      # model = Post::PostModel.new(...)
      # model.save
      # Post::ShowPage.new
      Post::ShowPage.new
    end
  end
end
