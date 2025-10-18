module AzuCli
  struct Post::IndexRequest
    include Azu::Request

    # Pagination and filtering parameters
    property page : Int32 = 1
    property per_page : Int32 = 20
    property sort_by : String?
    property order : String = "asc"

    property name : String?
    property content : String?
  end
end
