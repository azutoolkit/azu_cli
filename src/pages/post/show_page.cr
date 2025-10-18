module AzuCli
  struct Post::ShowPage
    include Azu::Response
    include Azu::Templates::Renderable

    def initialize(@post : Post::PostModel? = nil,
                   @csrf_token : String = "",
                   @csrf_tag : String = "",
                   @csrf_metatag : String = "")
    end

    def render
      view data: {
        "post"         => post_to_hash,
        "csrf_token"   => @csrf_token,
        "csrf_tag"     => @csrf_tag,
        "csrf_metatag" => @csrf_metatag,
      }
    end

    def post_to_hash : Hash(String, String)
      return {} of String => String if @post.nil?

      resource = @post.not_nil!
      {
        "name"    => safe_to_s(resource.name),
        "content" => safe_to_s(resource.content),
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
