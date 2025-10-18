require "cql"

module Post
  class PostModel
    include CQL::Model(UUID)
    db_context BlogDB, :posts

    # Attribute accessors
    getter id : UUID
    getter name : String
    getter content : String
    getter created_at : Time
    getter updated_at : Time

    # Validations
    validate :name, presence: true
    validate :name, length: {min: 2, max: 100}
    validate :content, presence: true
    validate :content, length: {min: 2, max: 100}

    # Constructor
    def initialize(@name : String, @content : String)
    end

    # Scopes
    scope :by_name, ->(value : String) { where("name ILIKE ?", "%" + value + "%") }
  end
end
