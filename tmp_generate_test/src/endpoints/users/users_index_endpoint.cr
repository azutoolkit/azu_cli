struct UsersIndexEndpoint
  include Azu::Endpoint(UsersIndexRequest, UsersIndexResponse)

  get "/users"

  def call : UsersIndexResponse
    # TODO: Implement index action
    # Example:
    # users = UsersService.index(request)
    # UsersIndexResponse.new(users)
    UsersIndexResponse.new
  end
end
