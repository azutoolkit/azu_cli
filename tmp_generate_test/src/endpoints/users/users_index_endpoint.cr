module App
  struct Users::IndexEndpoint
    include Azu::Endpoint(Users::IndexRequest, Users::IndexResponse)

    # TODO: Add HTTP verb and route for index action
    # Example: get "/users"

    def call : Users::IndexResponse
      # TODO: Implement index action logic
      Users::IndexResponse.new
    end
  end
end
