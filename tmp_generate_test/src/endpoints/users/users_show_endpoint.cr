module App
  struct Users::ShowEndpoint
    include Azu::Endpoint(Users::ShowRequest, Users::ShowResponse)

    # TODO: Add HTTP verb and route for show action
    # Example: get "/users/:id"

    def call : Users::ShowResponse
      # TODO: Implement show action logic
      Users::ShowResponse.new
    end
  end
end
