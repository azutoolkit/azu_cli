module AzuCli::Post
  struct NewEndpoint
    include Azu::Endpoint(Post::NewRequest, Post::NewPage)

    get "/posts/new"

    def call : Post::NewPage
      # TODO: Implement new action logic
      # Example usage:
      # model = Post::PostModel.new(...)
      # model.save
      # Post::NewPage.new
      Post::NewPage.new
    end
  end
end
