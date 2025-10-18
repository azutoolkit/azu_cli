module AzuCli::Post
  struct IndexEndpoint
    include Azu::Endpoint(Post::IndexRequest, Post::IndexPage)

    get "/posts"

    def call : Post::IndexPage
      # TODO: Implement index action logic
      # Example usage:
      # model = Post::PostModel.new(...)
      # model.save
      # Post::IndexPage.new
      Post::IndexPage.new
    end
  end
end
