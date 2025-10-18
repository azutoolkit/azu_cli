module AzuCli
  struct Post::EditRequest
    include Azu::Request

    property id : Int64
  end
end
