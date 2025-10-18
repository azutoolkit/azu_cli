module AzuCli
  struct Post::IndexPage
    include Azu::Response
    include Azu::Templates::Renderable

    def initialize(@posts : Array(Post::PostModel) = [] of Post::PostModel,
                   @csrf_token : String = "",
                   @csrf_tag : String = "",
                   @csrf_metatag : String = "")
    end

    def render
      view data: {
        "posts"        => array_to_hash(@posts),
        "csrf_token"   => @csrf_token,
        "csrf_tag"     => @csrf_tag,
        "csrf_metatag" => @csrf_metatag,
      }
    end

    def array_to_hash(array : Array(Post::PostModel)) : Array(Hash(String, String))
      array.map { |post| convert_to_hash(post) }
    end

    def convert_to_hash(post : Post::PostModel) : Hash(String, String)
      {
        "name"    => safe_to_s(post.name),
        "content" => safe_to_s(post.content),
      }
    end

    # Safely convert any value to string, handling nil and complex types
    private def safe_to_s(value : String) : String
      value
    end

    private def safe_to_s(value : Bool) : String
      value ? "true" : "false"
    end

    private def safe_to_s(value : Time) : String
      value.to_s("%Y-%m-%d %H:%M:%S")
    end

    private def safe_to_s(value : Nil) : String
      ""
    end

    private def safe_to_s(value) : String
      value.to_s
    end
  end
end
