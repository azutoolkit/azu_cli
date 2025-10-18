module AzuCli
  struct Post::DestroyRequest
    include Azu::Request

    property id : Int64
  end
end
