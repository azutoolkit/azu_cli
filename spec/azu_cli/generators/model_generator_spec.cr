require "spec"
require "file_utils"
require "teeplate"
require "../../../src/azu_cli/generators/base"
require "../../../src/azu_cli/generators/model_generator"

module AzuCLI::Generators
  describe ModelGenerator do
    it "generates a CQL model with attributes, associations, and validations" do
      model_name = "user"
      output_dir = "./tmp"
      output_file = File.join(output_dir, "models", "user.cr")

      # Define model attributes
      attributes = [
        {name: "id", type: "Int64", nullable: false},
        {name: "name", type: "String", nullable: false},
        {name: "email", type: "String", nullable: false},
        {name: "age", type: "Int32", nullable: true},
        {name: "profile_image_url", type: "String", nullable: true},
        {name: "created_at", type: "Time", nullable: false},
        {name: "updated_at", type: "Time", nullable: false},
      ]

      # Define associations
      associations = [
        {type: "has_many", name: "posts", model: "Post", foreign_key: "user_id"},
        {type: "has_one", name: "profile", model: "UserProfile", foreign_key: "user_id"},
      ]

      # Define validations
      validations = [
        {field: "name", rules: ["presence: true", "length: {min: 2}"]},
        {field: "email", rules: ["presence: true", "uniqueness: true", "format: EmailValidator::EMAIL_REGEX"]},
      ]

      FileUtils.mkdir_p(File.dirname(output_file))
      File.delete(output_file) if File.exists?(output_file)

      generator = ModelGenerator.new(model_name, attributes, associations, validations, output_dir)
      generated_path = generator.generate!

      generated_path.should eq(output_file)
      File.exists?(output_file).should be_true
      content = File.read(output_file)

      # Check basic structure
      content.should contain("require \"cql\"")
      content.should contain("struct User")
      content.should contain("include CQL::Model(Int64)")
      content.should contain("db_context ExampleDB, :users")

      # Check dynamic attributes
      content.should contain("property id : Int64")
      content.should contain("property name : String")
      content.should contain("property email : String")
      content.should contain("property age : Int32?")
      content.should contain("property profile_image_url : String?")
      content.should contain("property created_at : Time")
      content.should contain("property updated_at : Time")

      # Check associations
      content.should contain("has_many :posts, Post, foreign_key: :user_id")
      content.should contain("has_one :profile, UserProfile, foreign_key: :user_id")

      # Check validations
      content.should contain("validates :name, presence: true, length: {min: 2}")
      content.should contain("validates :email, presence: true, uniqueness: true, format: EmailValidator::EMAIL_REGEX")

      # Clean up
      File.delete(output_file) if File.exists?(output_file)
      FileUtils.rm_rf(File.dirname(output_file)) if Dir.exists?(File.dirname(output_file))
    end

    it "generates model with minimal configuration" do
      model_name = "post"
      output_dir = "./tmp"
      output_file = File.join(output_dir, "models", "post.cr")

      # Only basic attributes
      attributes = [
        {name: "title", type: "String", nullable: false},
        {name: "content", type: "String", nullable: true},
      ]

      FileUtils.mkdir_p(File.dirname(output_file))
      File.delete(output_file) if File.exists?(output_file)

      generator = ModelGenerator.new(model_name, attributes, [] of AssociationDefinition, [] of ValidationDefinition, output_dir)
      generated_path = generator.generate!

      generated_path.should eq(output_file)
      File.exists?(output_file).should be_true
      content = File.read(output_file)

      # Check basic structure
      content.should contain("struct Post")
      content.should contain("db_context ExampleDB, :posts")

      # Check attributes
      content.should contain("property title : String")
      content.should contain("property content : String?")

      # Should not contain associations or validations sections
      content.should_not contain("# Associations")
      content.should_not contain("# Validations")

      # Clean up
      File.delete(output_file) if File.exists?(output_file)
      FileUtils.rm_rf(File.dirname(output_file)) if Dir.exists?(File.dirname(output_file))
    end
  end
end
