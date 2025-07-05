struct UsersShowEndpoint
  include Azu::Endpoint(UsersShowRequest, UsersShowResponse)

  get "/users/:id"

  def call : UsersShowResponse
    # TODO: Implement show action
    # Example:
    # users = UsersService.show(request)
    # UsersShowResponse.new(users)
    UsersShowResponse.new
  end
end
