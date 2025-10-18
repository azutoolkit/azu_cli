module AzuCli
  struct Post::CreateRequest
    include Azu::Request

    property name : String
    property content : String
  end
end
