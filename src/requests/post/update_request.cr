module AzuCli
  struct Post::UpdateRequest
    include Azu::Request

    property id : Int64

    property name : String
    property content : String
  end
end
