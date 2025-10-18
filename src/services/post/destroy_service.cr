require "../result"

module Post
  class DestroyService
    def call(id : UUID | Int64) : Services::Result(Post::PostModel)
      post = Post::PostModel.find(id)

      if post.delete
        Services::Result.success(post)
      else
        Services::Result.failure(post.errors)
      end
    rescue CQL::RecordNotFound
      errors = CQL::ActiveRecord::Validations::Errors.new
      errors << CQL::ActiveRecord::Validations::Error.new(:base, "Record not found")
      Services::Result(Post::PostModel).failure(errors)
    end
  end
end
