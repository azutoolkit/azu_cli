module AzuCli::Post
  struct EditEndpoint
    include Azu::Endpoint(Post::EditRequest, Post::EditPage)

    get "/posts/:id/edit"

    def call : Post::EditPage
      # TODO: Implement edit action logic
      # Example usage:
      # model = Post::PostModel.new(...)
      # model.save
      # Post::EditPage.new
      Post::EditPage.new
    end
  end
end
