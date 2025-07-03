require "spec"
require "file_utils"
require "teeplate"
require "../../../src/azu_cli/generators/base"
require "../../../src/azu_cli/generators/model_generator"
require "../../spec_helper"

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

    describe "#initialize" do
      it "creates generator with valid model name" do
        generator = ModelGenerator.new("user")
        generator.name.should eq("user")
        generator.model_name.should eq("user")
        generator.output_dir.should eq("src")
        generator.generate_specs.should be_true
      end

      it "creates generator with attributes" do
        attributes = [
          {name: "name", type: "String", nullable: false},
          {name: "email", type: "String", nullable: false}
        ]
        generator = ModelGenerator.new("user", attributes)
        generator.attributes.size.should eq(2)
        generator.attributes.first[:name].should eq("name")
      end

      it "creates generator with associations" do
        associations = [
          {type: "has_many", name: "posts", model: "Post", foreign_key: "user_id"}
        ]
        generator = ModelGenerator.new("user", associations: associations)
        generator.associations.size.should eq(1)
        generator.associations.first[:type].should eq("has_many")
      end

      it "creates generator with validations" do
        validations = [
          {field: "email", rules: ["required", "unique"]}
        ]
        generator = ModelGenerator.new("user", validations: validations)
        generator.validations.size.should eq(1)
        generator.validations.first[:field].should eq("email")
      end

      it "raises error for empty model name" do
        expect_raises(ArgumentError, "Name cannot be empty") do
          ModelGenerator.new("")
        end
      end

      it "raises error for invalid model name" do
        expect_raises(ArgumentError, "Name must be a valid identifier") do
          ModelGenerator.new("123invalid")
        end
      end
    end

    describe "#template_directory" do
      it "returns correct template directory" do
        generator = ModelGenerator.new("user")
        generator.template_directory.should contain("templates/generators/model")
      end
    end

    describe "#build_output_path" do
      it "returns correct output path for model file" do
        generator = ModelGenerator.new("user")
        generator.build_output_path.should eq("src/models/user.cr")
      end

      it "returns correct output path with custom directory" do
        generator = ModelGenerator.new("user", output_dir: "custom_src")
        generator.build_output_path.should eq("custom_src/models/user.cr")
      end
    end

    describe "#spec_template_name" do
      it "returns correct spec template name" do
        generator = ModelGenerator.new("user")
        generator.spec_template_name.should eq("{{model_name}}_spec.cr.ecr")
      end
    end

    describe "#model_name_camelcase" do
      it "converts model name to camelcase" do
        generator = ModelGenerator.new("user_profile")
        generator.model_name_camelcase.should eq("UserProfile")
      end

      it "handles single word model names" do
        generator = ModelGenerator.new("user")
        generator.model_name_camelcase.should eq("User")
      end
    end

    describe "#model_name_pluralized" do
      it "pluralizes model name" do
        generator = ModelGenerator.new("user")
        generator.model_name_pluralized.should eq("users")
      end

      it "handles already pluralized names" do
        generator = ModelGenerator.new("users")
        generator.model_name_pluralized.should eq("users")
      end
    end

    describe "ModelConfiguration" do
      it "creates configuration with attributes" do
        attributes = [
          {name: "name", type: "String", nullable: false}
        ]
        config = ModelConfiguration.new(attributes)
        config.has_attributes?.should be_true
        config.attributes.size.should eq(1)
      end

      it "creates configuration with associations" do
        associations = [
          {type: "belongs_to", name: "user", model: "User", foreign_key: "user_id"}
        ]
        config = ModelConfiguration.new(associations: associations)
        config.has_associations?.should be_true
        config.associations.size.should eq(1)
      end

      it "creates configuration with validations" do
        validations = [
          {field: "name", rules: ["required"]}
        ]
        config = ModelConfiguration.new(validations: validations)
        config.has_validations?.should be_true
        config.validations.size.should eq(1)
      end

      it "handles empty configuration" do
        config = ModelConfiguration.new
        config.has_attributes?.should be_false
        config.has_associations?.should be_false
        config.has_validations?.should be_false
      end
    end

    describe "#validate_preconditions!" do
      it "validates attributes" do
        attributes = [
          {name: "", type: "String", nullable: false}
        ]
        generator = ModelGenerator.new("user", attributes)
        expect_raises(ArgumentError, "Attribute name cannot be empty") do
          generator.validate_preconditions!
        end
      end

      it "validates attribute types" do
        attributes = [
          {name: "name", type: "", nullable: false}
        ]
        generator = ModelGenerator.new("user", attributes)
        expect_raises(ArgumentError, "Attribute type cannot be empty") do
          generator.validate_preconditions!
        end
      end

      it "validates associations" do
        associations = [
          {type: "has_many", name: "", model: "Post", foreign_key: "user_id"}
        ]
        generator = ModelGenerator.new("user", associations: associations)
        expect_raises(ArgumentError, "Association name cannot be empty") do
          generator.validate_preconditions!
        end
      end

      it "validates validations" do
        validations = [
          {field: "", rules: ["required"]}
        ]
        generator = ModelGenerator.new("user", validations: validations)
        expect_raises(ArgumentError, "Validation field cannot be empty") do
          generator.validate_preconditions!
        end
      end

      it "validates validation rules" do
        validations = [
          {field: "name", rules: [] of String}
        ]
        generator = ModelGenerator.new("user", validations: validations)
        expect_raises(ArgumentError, "Validation rules cannot be empty") do
          generator.validate_preconditions!
        end
      end
    end

    describe "integration" do
      it "creates complete model with all features" do
        attributes = [
          {name: "name", type: "String", nullable: false},
          {name: "email", type: "String", nullable: false},
          {name: "age", type: "Int32", nullable: true}
        ]
        associations = [
          {type: "has_many", name: "posts", model: "Post", foreign_key: "user_id"},
          {type: "belongs_to", name: "company", model: "Company", foreign_key: "company_id"}
        ]
        validations = [
          {field: "name", rules: ["required", "min_length(2)"]},
          {field: "email", rules: ["required", "unique", "format(email)"]}
        ]

        generator = ModelGenerator.new("user", attributes, associations, validations)
        generator.attributes.size.should eq(3)
        generator.associations.size.should eq(2)
        generator.validations.size.should eq(2)
        generator.model_name_camelcase.should eq("User")
        generator.model_name_pluralized.should eq("users")
      end
    end
  end
end
