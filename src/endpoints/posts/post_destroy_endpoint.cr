module AzuCli::Post
  struct DestroyEndpoint
    include Azu::Endpoint(Post::DestroyRequest, Post::DestroyPage)

    delete "/posts/:id"

    def call : Post::DestroyPage
      # TODO: Implement destroy action logic
      # Example usage:
      # model = Post::PostModel.new(...)
      # model.save
      # Post::DestroyPage.new
      Post::DestroyPage.new
    end
  end
end
