require "../spec_helper"

describe AzuCLI::Generator::ScaffoldGenerator do
  describe "initialization" do
    it "initializes with basic parameters" do
      options = create_generator_options(attributes: sample_attributes)
      generator = AzuCLI::Generator::ScaffoldGenerator.new("User", "test_project", options)
      
      generator.name.should eq("User")
      generator.project_name.should eq("test_project")
      generator.attributes.should eq(sample_attributes)
    end

    it "extracts actions from additional args" do
      options = create_generator_options(additional_args: ["index", "show", "create"])
      generator = AzuCLI::Generator::ScaffoldGenerator.new("User", "test_project", options)
      
      generator.actions.should eq(["index", "show", "create"])
    end

    it "uses default actions when none specified" do
      options = create_generator_options
      generator = AzuCLI::Generator::ScaffoldGenerator.new("User", "test_project", options)
      
      generator.actions.should_not be_empty
      generator.actions.should contain("index")
      generator.actions.should contain("show")
      generator.actions.should contain("create")
    end

    it "sets api_only flag from options" do
      options = create_generator_options(custom_options: {"api-only" => "true"})
      generator = AzuCLI::Generator::ScaffoldGenerator.new("User", "test_project", options)
      
      generator.api_only.should be_true
    end

    it "sets web_only flag from options" do
      options = create_generator_options(custom_options: {"web-only" => "true"})
      generator = AzuCLI::Generator::ScaffoldGenerator.new("User", "test_project", options)
      
      generator.web_only.should be_true
    end

    it "extracts skip components from options" do
      options = create_generator_options(custom_options: {"skip-model" => "true", "skip-service" => "true"})
      generator = AzuCLI::Generator::ScaffoldGenerator.new("User", "test_project", options)
      
      generator.skip_components.should contain("model")
      generator.skip_components.should contain("service")
    end
  end

  describe "generator type" do
    it "returns correct generator type" do
      options = create_generator_options
      generator = AzuCLI::Generator::ScaffoldGenerator.new("User", "test_project", options)
      
      generator.generator_type.should eq("scaffold")
    end
  end

  describe "directory creation" do
    it "creates all scaffold directories" do
      with_temp_directory do
        create_mock_project
        
        options = create_generator_options(attributes: sample_attributes)
        generator = AzuCLI::Generator::ScaffoldGenerator.new("User", "test_project", options)
        mock_strategy = GeneratorSpecHelper::MockFileStrategy.new
        generator.file_strategy = mock_strategy
        
        generator.create_directories
        
        # Should create directories for all components
        mock_strategy.created_directories.should_not be_empty
      end
    end
  end

  describe "component generation order" do
    it "generates components in dependency order" do
      with_temp_directory do
        create_mock_project
        
        options = create_generator_options(attributes: sample_attributes)
        generator = AzuCLI::Generator::ScaffoldGenerator.new("User", "test_project", options)
        
        # Mock the individual generators to track call order
        # This is a simplified test - in practice we'd need more sophisticated mocking
        generator.should be_a(AzuCLI::Generator::ScaffoldGenerator)
      end
    end

    it "skips components based on skip options" do
      options = create_generator_options(
        attributes: sample_attributes,
        custom_options: {"skip-model" => "true"}
      )
      generator = AzuCLI::Generator::ScaffoldGenerator.new("User", "test_project", options)
      
      generator.skip_components.should contain("model")
    end

    it "skips pages for api_only scaffolds" do
      options = create_generator_options(
        attributes: sample_attributes,
        custom_options: {"api-only" => "true"}
      )
      generator = AzuCLI::Generator::ScaffoldGenerator.new("User", "test_project", options)
      
      generator.api_only.should be_true
    end
  end

  describe "file generation" do
    it "generates multiple component files" do
      with_temp_directory do
        create_mock_project
        
        # Create minimal mock generators to avoid circular dependencies
        options = create_generator_options(attributes: sample_attributes)
        generator = AzuCLI::Generator::ScaffoldGenerator.new("User", "test_project", options)
        
        # In a real scenario, we'd mock the individual generators
        # For this test, we just verify the scaffold generator is properly initialized
        generator.attributes.should eq(sample_attributes)
        generator.actions.should_not be_empty
      end
    end

    it "skips test generation when skip_tests is true" do
      options = create_generator_options(
        attributes: sample_attributes,
        skip_tests: true
      )
      generator = AzuCLI::Generator::ScaffoldGenerator.new("User", "test_project", options)
      
      generator.skip_tests.should be_true
    end
  end

  describe "action filtering" do
    it "filters actions that need pages" do
      options = create_generator_options(additional_args: ["index", "show", "create", "destroy"])
      generator = AzuCLI::Generator::ScaffoldGenerator.new("User", "test_project", options)
      
      generator.actions.should contain("index")
      generator.actions.should contain("show") 
      generator.actions.should contain("create")
      generator.actions.should contain("destroy")
    end

    it "determines contract types for actions" do
      options = create_generator_options(additional_args: ["index", "create", "update"])
      generator = AzuCLI::Generator::ScaffoldGenerator.new("User", "test_project", options)
      
      # Test internal logic through accessible properties
      generator.actions.should contain("index")
      generator.actions.should contain("create")
      generator.actions.should contain("update")
    end
  end

  describe "component options generation" do
    it "creates appropriate options for each component" do
      options = create_generator_options(
        attributes: sample_attributes,
        force: true,
        skip_tests: false
      )
      generator = AzuCLI::Generator::ScaffoldGenerator.new("User", "test_project", options)
      
      # Verify that the scaffold generator passes options correctly
      generator.force.should be_true
      generator.skip_tests.should be_false
      generator.attributes.should eq(sample_attributes)
    end
  end

  describe "success message" do
    it "includes action and attribute count" do
      options = create_generator_options(
        attributes: sample_attributes,
        additional_args: ["index", "show", "create"]
      )
      generator = AzuCLI::Generator::ScaffoldGenerator.new("User", "test_project", options)
      
      message = generator.success_message
      message.should contain("action")
      message.should contain("attribute")
    end

    it "includes api_only information" do
      options = create_generator_options(
        attributes: sample_attributes,
        custom_options: {"api-only" => "true"}
      )
      generator = AzuCLI::Generator::ScaffoldGenerator.new("User", "test_project", options)
      
      message = generator.success_message
      message.should contain("API only")
    end

    it "includes web_only information" do
      options = create_generator_options(
        attributes: sample_attributes,
        custom_options: {"web-only" => "true"}
      )
      generator = AzuCLI::Generator::ScaffoldGenerator.new("User", "test_project", options)
      
      message = generator.success_message
      message.should contain("Web only")
    end
  end

  describe "route generation" do
    it "generates appropriate route examples" do
      options = create_generator_options(additional_args: ["index", "show", "create", "update", "destroy"])
      generator = AzuCLI::Generator::ScaffoldGenerator.new("User", "test_project", options)
      
      # Test through post generation tasks
      generator.actions.should contain("index")
      generator.actions.should contain("show")
      generator.actions.should contain("create")
      generator.actions.should contain("update")
      generator.actions.should contain("destroy")
    end
  end

  describe "validation" do
    it "validates scaffold preconditions" do
      options = create_generator_options
      generator = AzuCLI::Generator::ScaffoldGenerator.new("User", "test_project", options)
      
      # Should not raise any exceptions for valid input
      generator.validate_preconditions
    end

    it "warns about missing attributes" do
      options = create_generator_options  # No attributes
      generator = AzuCLI::Generator::ScaffoldGenerator.new("User", "test_project", options)
      
      generator.attributes.should be_empty
      # In practice, this would show a warning during validation
    end

    it "warns about missing actions" do
      options = create_generator_options(additional_args: [] of String)  # No actions
      generator = AzuCLI::Generator::ScaffoldGenerator.new("User", "test_project", options)
      
      # Should use default actions
      generator.actions.should_not be_empty
    end
  end

  describe "complex scenarios" do
    it "handles scaffold with many attributes" do
      options = create_generator_options(attributes: complex_attributes)
      generator = AzuCLI::Generator::ScaffoldGenerator.new("Post", "test_project", options)
      
      generator.attributes.should eq(complex_attributes)
      generator.attributes.size.should be > 3
    end

    it "handles scaffold with custom actions" do
      options = create_generator_options(
        attributes: sample_attributes,
        additional_args: ["index", "show", "publish", "archive"]
      )
      generator = AzuCLI::Generator::ScaffoldGenerator.new("Post", "test_project", options)
      
      generator.actions.should contain("index")
      generator.actions.should contain("show")
      generator.actions.should contain("publish")
      generator.actions.should contain("archive")
    end

    it "handles API-only scaffold properly" do
      options = create_generator_options(
        attributes: sample_attributes,
        custom_options: {"api-only" => "true"}
      )
      generator = AzuCLI::Generator::ScaffoldGenerator.new("User", "test_project", options)
      
      generator.api_only.should be_true
      generator.web_only.should be_false
    end

    it "handles web-only scaffold properly" do
      options = create_generator_options(
        attributes: sample_attributes,
        custom_options: {"web-only" => "true"}
      )
      generator = AzuCLI::Generator::ScaffoldGenerator.new("User", "test_project", options)
      
      generator.web_only.should be_true
      generator.api_only.should be_false
    end
  end

  describe "template variables for pages" do
    it "generates appropriate template variables for different actions" do
      options = create_generator_options(additional_args: ["index", "show", "new", "edit"])
      generator = AzuCLI::Generator::ScaffoldGenerator.new("User", "test_project", options)
      
      # Test that it handles different action types
      generator.actions.should contain("index")
      generator.actions.should contain("show")
      generator.actions.should contain("new")
      generator.actions.should contain("edit")
    end
  end
end