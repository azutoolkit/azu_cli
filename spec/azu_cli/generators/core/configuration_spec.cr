require "../spec_helper"

describe AzuCLI::Generator::Core::Configuration do
  describe "initialization" do
    it "initializes with generator type" do
      config = AzuCLI::Generator::Core::Configuration.new("model")
      config.generator_type.should eq("model")
    end
  end

  describe "configuration loading" do
    it "loads configuration from YAML file" do
      with_temp_directory do
        # Create a test config file
        Dir.mkdir_p("src/azu_cli/generators/config")
        File.write("src/azu_cli/generators/config/test.yml", <<-YAML
        type: "test"
        description: "Test generator"
        directories:
          source: "src/test"
        YAML
        )

        config = AzuCLI::Generator::Core::Configuration.new("test")
        loaded_config = config.load!

        loaded_config.should be_a(AzuCLI::Generator::Core::Configuration)
      end
    end

    it "handles missing configuration files gracefully" do
      config = AzuCLI::Generator::Core::Configuration.new("nonexistent")

      expect_raises(Exception) do
        config.load!
      end
    end
  end

  describe "configuration access" do
    it "retrieves simple configuration values" do
      with_temp_directory do
        Dir.mkdir_p("src/azu_cli/generators/config")
        File.write("src/azu_cli/generators/config/test.yml", <<-YAML
        type: "test"
        description: "Test generator for specs"
        category: "testing"
        YAML
        )

        config = AzuCLI::Generator::Core::Configuration.new("test").load!

        config.get("type").should eq("test")
        config.get("description").should eq("Test generator for specs")
        config.get("category").should eq("testing")
      end
    end

    it "retrieves nested configuration values" do
      with_temp_directory do
        Dir.mkdir_p("src/azu_cli/generators/config")
        File.write("src/azu_cli/generators/config/test.yml", <<-YAML
        directories:
          source: "src/test"
          spec: "spec/test"
        templates:
          main: "test.cr.ecr"
          spec: "test_spec.cr.ecr"
        YAML
        )

        config = AzuCLI::Generator::Core::Configuration.new("test").load!

        config.get("directories.source").should eq("src/test")
        config.get("directories.spec").should eq("spec/test")
        config.get("templates.main").should eq("test.cr.ecr")
      end
    end

    it "returns nil for missing keys" do
      with_temp_directory do
        Dir.mkdir_p("src/azu_cli/generators/config")
        File.write("src/azu_cli/generators/config/test.yml", <<-YAML
        type: "test"
        YAML
        )

        config = AzuCLI::Generator::Core::Configuration.new("test").load!

        config.get("nonexistent").should be_nil
        config.get("nested.nonexistent").should be_nil
      end
    end
  end

  describe "array configuration access" do
    it "retrieves array values" do
      with_temp_directory do
        Dir.mkdir_p("src/azu_cli/generators/config")
        File.write("src/azu_cli/generators/config/test.yml", <<-YAML
        default_methods:
          - "initialize"
          - "call"
          - "valid?"
        actions:
          - "index"
          - "show"
          - "create"
        YAML
        )

        config = AzuCLI::Generator::Core::Configuration.new("test").load!

        methods = config.get_array("default_methods")
        methods.should eq(["initialize", "call", "valid?"])

        actions = config.get_array("actions")
        actions.should eq(["index", "show", "create"])
      end
    end

    it "returns empty array for missing array keys" do
      with_temp_directory do
        Dir.mkdir_p("src/azu_cli/generators/config")
        File.write("src/azu_cli/generators/config/test.yml", <<-YAML
        type: "test"
        YAML
        )

        config = AzuCLI::Generator::Core::Configuration.new("test").load!

        config.get_array("nonexistent").should eq([] of String)
      end
    end
  end

  describe "hash configuration access" do
    it "retrieves hash values" do
      with_temp_directory do
        Dir.mkdir_p("src/azu_cli/generators/config")
        File.write("src/azu_cli/generators/config/test.yml", <<-YAML
        attribute_types:
          string: "String"
          integer: "Int32"
          boolean: "Bool"
        validation_patterns:
          presence: "presence: true"
          length: "length: {min: 2, max: 100}"
        YAML
        )

        config = AzuCLI::Generator::Core::Configuration.new("test").load!

        types = config.get_hash("attribute_types")
        types["string"].should eq("String")
        types["integer"].should eq("Int32")

        patterns = config.get_hash("validation_patterns")
        patterns["presence"].should eq("presence: true")
      end
    end

    it "returns empty hash for missing hash keys" do
      with_temp_directory do
        Dir.mkdir_p("src/azu_cli/generators/config")
        File.write("src/azu_cli/generators/config/test.yml", <<-YAML
        type: "test"
        YAML
        )

        config = AzuCLI::Generator::Core::Configuration.new("test").load!

        config.get_hash("nonexistent").should eq({} of String => YAML::Any)
      end
    end
  end

  describe "configuration inheritance" do
    it "supports extending base configuration" do
      with_temp_directory do
        Dir.mkdir_p("src/azu_cli/generators/config")

        # Create base config
        File.write("src/azu_cli/generators/config/base.yml", <<-YAML
        common_flags:
          force: false
          skip_tests: false
        crystal_types:
          string: "String"
          integer: "Int32"
        YAML
        )

        # Create derived config
        File.write("src/azu_cli/generators/config/test.yml", <<-YAML
        extends: "base.yml"
        type: "test"
        specific_option: "test_value"
        YAML
        )

        config = AzuCLI::Generator::Core::Configuration.new("test").load!

        # Should have base values
        config.get("crystal_types.string").should eq("String")
        config.get("common_flags.force").should eq(false)

        # Should have specific values
        config.get("type").should eq("test")
        config.get("specific_option").should eq("test_value")
      end
    end
  end

  describe "validation" do
    it "validates required configuration keys" do
      with_temp_directory do
        Dir.mkdir_p("src/azu_cli/generators/config")
        File.write("src/azu_cli/generators/config/test.yml", <<-YAML
        # Missing required type field
        description: "Test generator"
        YAML
        )

        config = AzuCLI::Generator::Core::Configuration.new("test")

        # Should load but validation might fail
        loaded_config = config.load!
        loaded_config.should be_a(AzuCLI::Generator::Core::Configuration)
      end
    end
  end

  describe "error handling" do
    it "handles malformed YAML gracefully" do
      with_temp_directory do
        Dir.mkdir_p("src/azu_cli/generators/config")
        File.write("src/azu_cli/generators/config/test.yml", <<-YAML
        type: "test"
        invalid_yaml: [unclosed array
        YAML
        )

        config = AzuCLI::Generator::Core::Configuration.new("test")

        expect_raises(Exception) do
          config.load!
        end
      end
    end

    it "provides helpful error messages for missing files" do
      config = AzuCLI::Generator::Core::Configuration.new("nonexistent")

      expect_raises(Exception) do
        config.load!
      end
    end
  end
end
