module Services
  # Result object for service operations
  class Result(T)
    property success : Bool
    property data : T?
    property errors : CQL::ActiveRecord::Validations::Errors

    def initialize(@success : Bool, @data : T? = nil, @errors : CQL::ActiveRecord::Validations::Errors = CQL::ActiveRecord::Validations::Errors.new)
    end

    def self.success(data : T) : Result(T)
      new(success: true, data: data)
    end

    def self.failure(errors : CQL::ActiveRecord::Validations::Errors) : Result(T)
      new(success: false, errors: errors)
    end

    def success? : Bool
      @success
    end

    def failure? : Bool
      !@success
    end
  end
end
