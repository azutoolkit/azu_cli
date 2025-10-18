require "../result"

module Post
  class IndexService
    def call : Services::Result(Array(Post::PostModel))
      records = Post::PostModel.all
      Services::Result.success(records.to_a)
    end
  end
end
