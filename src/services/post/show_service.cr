require "../result"

module Post
  class ShowService
    def call(id : UUID | Int64) : Services::Result(Post::PostModel)
      post = Post::PostModel.find(id)
      Services::Result.success(post)
    rescue CQL::RecordNotFound
      errors = CQL::ActiveRecord::Validations::Errors.new
      errors << CQL::ActiveRecord::Validations::Error.new(:base, "Record not found")
      Services::Result(Post::PostModel).failure(errors)
    end
  end
end