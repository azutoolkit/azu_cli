module AzuCli::Post
  struct CreateEndpoint
    include Azu::Endpoint(Post::CreateRequest, Post::CreatePage)

    post "/posts"

    def call : Post::CreatePage
      # TODO: Implement create action logic
      # Example usage:
      # model = Post::PostModel.new(...)
      # model.save
      # Post::CreatePage.new
      Post::CreatePage.new
    end
  end
end
