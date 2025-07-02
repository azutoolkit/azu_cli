require "spec"
require "../../../src/azu_cli"
require "../../../src/azu_cli/generators/core/factory"
require "file_utils"

# Generator Spec Helper
# Provides common utilities and fixtures for testing generators

module GeneratorSpecHelper
  # Create a temporary directory for testing
  def with_temp_directory(&block)
    temp_dir = File.tempname("azu_generator_test")
    Dir.mkdir_p(temp_dir)

    begin
      Dir.cd(temp_dir) do
        yield temp_dir
      end
    ensure
      FileUtils.rm_rf(temp_dir) if Dir.exists?(temp_dir)
    end
  end

  # Create a mock project structure
  def create_mock_project(project_name : String = "test_project")
    Dir.mkdir_p("src")
    Dir.mkdir_p("spec")
    Dir.mkdir_p("src/#{project_name}")
    Dir.mkdir_p("spec/#{project_name}")

    # Create basic shard.yml
    File.write("shard.yml", <<-YAML
    name: #{project_name}
    version: 0.1.0

    dependencies:
      azu:
        github: azutoolkit/azu
      cql:
        github: azutoolkit/cql
    YAML
    )
  end

  # Create generator options with common defaults
  def create_generator_options(
    force : Bool = false,
    skip_tests : Bool = false,
    attributes : Hash(String, String) = {} of String => String,
    additional_args : Array(String) = [] of String,
    custom_options : Hash(String, String) = {} of String => String,
  ) : AzuCLI::Generator::Core::GeneratorOptions
    AzuCLI::Generator::Core::GeneratorOptions.new(
      force: force,
      skip_tests: skip_tests,
      attributes: attributes,
      additional_args: additional_args,
      custom_options: custom_options
    )
  end

  # Mock file strategy for testing without actual file creation
  class MockFileStrategy < AzuCLI::Generator::Core::FileCreationStrategy
    property created_files : Array(String)
    property created_directories : Array(String)
    property file_contents : Hash(String, String)

    def initialize
      @created_files = [] of String
      @created_directories = [] of String
      @file_contents = {} of String => String
    end

    def create_file(path : String, content : String, options : Hash(String, String) = {} of String => String) : Bool
      @created_files << path
      @file_contents[path] = content
      true
    end

    def create_directory(path : String) : Bool
      @created_directories << path
      true
    end

    def file_exists?(path : String) : Bool
      @created_files.includes?(path)
    end

    def directory_exists?(path : String) : Bool
      @created_directories.includes?(path)
    end
  end

  # Sample attributes for testing
  def sample_attributes
    {
      "name"   => "string",
      "email"  => "string",
      "age"    => "integer",
      "active" => "boolean",
    }
  end

  # Sample complex attributes
  def complex_attributes
    {
      "title"        => "string",
      "content"      => "text",
      "published_at" => "datetime",
      "author_id"    => "integer",
      "view_count"   => "integer",
      "featured"     => "boolean",
      "tags"         => "array",
    }
  end
end

# Include helper in all generator specs
include GeneratorSpecHelper
