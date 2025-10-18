module AzuCli::Post
  struct UpdateEndpoint
    include Azu::Endpoint(Post::UpdateRequest, Post::UpdatePage)

    patch "/posts/:id"

    def call : Post::UpdatePage
      # TODO: Implement update action logic
      # Example usage:
      # model = Post::PostModel.new(...)
      # model.save
      # Post::UpdatePage.new
      Post::UpdatePage.new
    end
  end
end
