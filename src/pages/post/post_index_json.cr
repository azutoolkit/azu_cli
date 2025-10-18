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
        "name"    => post.name.to_s,
        "content" => post.content.to_s,
      }
    end
  end
end
