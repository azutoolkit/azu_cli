require "../result"

module Post
  class CreateService
    def call(name : String, content : String) : Services::Result(Post::PostModel)
      post = Post::PostModel.new(name: name, content: content)
      
      if post.save
        Services::Result.success(post)
      else
        Services::Result.failure(post.errors)
      end
    end
  end
end