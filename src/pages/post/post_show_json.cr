module AzuCli
  struct Post::ShowPage
    include Azu::Response
    include Azu::Templates::Renderable

      def initialize(@post : Post::PostModel? = nil)
    end

    def render
      view data: {
        "post" => post_to_hash,
      }
    end

    def post_to_hash
      return {} of String => String if @post.nil?

      {
        "name" => @post.try(&.name),
        "content" => @post.try(&.content),
      }
    end
    end
end
