module AzuCli
  struct Post::ShowRequest
    include Azu::Request

    property id : Int64
  end
end
