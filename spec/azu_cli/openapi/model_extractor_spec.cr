require "../../spec_helper"

describe AzuCLI::OpenAPI::ModelExtractor do
  describe "#extract" do
    it "extracts models from Crystal files" do
      Dir.mkdir_p("spec/fixtures/test_project/src/models")

      model_content = <<-CRYSTAL
      struct User
        property name : String
        property email : String
        property age : Int32
      end
      CRYSTAL

      File.write("spec/fixtures/test_project/src/models/user.cr", model_content)

      extractor = AzuCLI::OpenAPI::ModelExtractor.new("spec/fixtures/test_project")
      models = extractor.extract

      models.size.should eq(1)
      models[0].name.should eq("User")
      models[0].properties.size.should eq(3)
      models[0].properties["name"].should eq("String")
      models[0].properties["email"].should eq("String")
      models[0].properties["age"].should eq("Int32")

      File.delete("spec/fixtures/test_project/src/models/user.cr")
      Dir.delete("spec/fixtures/test_project/src/models")
      Dir.delete("spec/fixtures/test_project/src")
      Dir.delete("spec/fixtures/test_project")
    end

    it "extracts properties with getter" do
      Dir.mkdir_p("spec/fixtures/test_project/src/models")

      model_content = <<-CRYSTAL
      struct Post
        getter title : String
        getter content : String
        property published : Bool
      end
      CRYSTAL

      File.write("spec/fixtures/test_project/src/models/post.cr", model_content)

      extractor = AzuCLI::OpenAPI::ModelExtractor.new("spec/fixtures/test_project")
      models = extractor.extract

      models.size.should eq(1)
      models[0].properties.size.should eq(3)
      models[0].properties.has_key?("title").should be_true
      models[0].properties.has_key?("content").should be_true
      models[0].properties.has_key?("published").should be_true

      File.delete("spec/fixtures/test_project/src/models/post.cr")
      Dir.delete("spec/fixtures/test_project/src/models")
      Dir.delete("spec/fixtures/test_project/src")
      Dir.delete("spec/fixtures/test_project")
    end

    it "returns empty array when no models exist" do
      Dir.mkdir_p("spec/fixtures/empty_project")

      extractor = AzuCLI::OpenAPI::ModelExtractor.new("spec/fixtures/empty_project")
      models = extractor.extract

      models.should be_empty

      Dir.delete("spec/fixtures/empty_project")
    end
  end
end
