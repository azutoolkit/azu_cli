require "../../spec_helper"

describe AzuCLI::Validators::JinjaValidator do
  describe ".validate" do
    it "detects invalid ternary operators" do
      template = "{{ user.name if user.name }}"
      result = AzuCLI::Validators::JinjaValidator.validate(template)

      result.valid.should be_false
      result.errors.size.should eq(1)
      result.errors.first.message.should contain("Invalid ternary operator syntax")
      result.errors.first.suggestion.should_not be_nil
      result.errors.first.suggestion.not_nil!.should contain("{% if user.name %}{{ user.name }}{% endif %}")
    end

    it "detects function calls in expressions" do
      template = "{{ csrf_token() }}"
      result = AzuCLI::Validators::JinjaValidator.validate(template)

      result.valid.should be_false
      result.errors.size.should eq(1)
      result.errors.first.message.should contain("Function call in template expression")
      result.errors.first.suggestion.should_not be_nil
      result.errors.first.suggestion.not_nil!.should contain("{{ csrf_token }}")
    end

    it "detects complex ternary operators" do
      template = "{{ post.title if post.title else 'No title' }}"
      result = AzuCLI::Validators::JinjaValidator.validate(template)

      result.valid.should be_false
      result.errors.size.should be >= 1
      result.errors.any? { |e| e.message.includes?("Invalid ternary operator") }.should be_true
    end

    it "validates correct Jinja syntax" do
      template = <<-JINJA
        {% if user %}
          <h1>{{ user.name }}</h1>
          {% if user.email %}
            <p>{{ user.email }}</p>
          {% endif %}
        {% endif %}
      JINJA

      result = AzuCLI::Validators::JinjaValidator.validate(template)

      result.valid.should be_true
      result.errors.size.should eq(0)
    end

    it "detects CSRF token function calls as warnings" do
      template = "{{ csrf_token() }}"
      result = AzuCLI::Validators::JinjaValidator.validate(template)

      result.warnings.size.should eq(1)
      result.warnings.first.message.should contain("CSRF token function call detected")
    end

    it "detects unclosed blocks as warnings" do
      template = "{% if user %}<h1>{{ user.name }}</h1>"
      result = AzuCLI::Validators::JinjaValidator.validate(template)

      result.warnings.size.should eq(1)
      result.warnings.first.message.should contain("If block opened but not closed")
    end

    it "handles multiple errors in one template" do
      template = <<-JINJA
        {{ user.name if user.name }}
        {{ csrf_token() }}
        {{ post.title if post.title else 'No title' }}
      JINJA

      result = AzuCLI::Validators::JinjaValidator.validate(template)

      result.valid.should be_false
      result.errors.size.should be >= 3
    end
  end

  describe ".validate_file" do
    it "validates a template file" do
      # Create a temporary template file
      temp_file = "/tmp/test_template.jinja"
      File.write(temp_file, "{{ user.name if user.name }}")

      result = AzuCLI::Validators::JinjaValidator.validate_file(temp_file)

      result.valid.should be_false
      result.errors.size.should eq(1)

      # Clean up
      File.delete(temp_file)
    end

    it "handles non-existent files" do
      result = AzuCLI::Validators::JinjaValidator.validate_file("/non/existent/file.jinja")

      result.valid.should be_false
      result.errors.size.should eq(1)
      result.errors.first.message.should contain("File not found")
    end
  end

  describe ".validate_files" do
    it "validates multiple template files" do
      # Create temporary template files
      temp_files = [
        "/tmp/test1.jinja",
        "/tmp/test2.jinja"
      ]

      File.write(temp_files[0], "{{ user.name if user.name }}")
      File.write(temp_files[1], "{% if user %}{{ user.name }}{% endif %}")

      results = AzuCLI::Validators::JinjaValidator.validate_files(temp_files)

      results.size.should eq(2)
      results[temp_files[0]].valid.should be_false
      results[temp_files[1]].valid.should be_true

      # Clean up
      temp_files.each { |file| File.delete(file) }
    end
  end

  describe ".validate_directory" do
    it "validates templates in a directory" do
      # Create a temporary directory with template files
      temp_dir = "/tmp/test_templates_#{Time.utc.to_unix}"
      Dir.mkdir(temp_dir)

      File.write(File.join(temp_dir, "test1.jinja"), "{{ user.name if user.name }}")
      File.write(File.join(temp_dir, "test2.jinja"), "{% if user %}{{ user.name }}{% endif %}")

      results = AzuCLI::Validators::JinjaValidator.validate_directory(temp_dir)

      results.size.should eq(2)
      results.values.any?(&.valid).should be_true
      results.values.any? { |r| !r.valid }.should be_true

      # Clean up
      File.delete(File.join(temp_dir, "test1.jinja"))
      File.delete(File.join(temp_dir, "test2.jinja"))
      Dir.delete(temp_dir)
    end

    it "handles non-existent directories" do
      results = AzuCLI::Validators::JinjaValidator.validate_directory("/non/existent/dir")

      results.size.should eq(1)
      results.values.first.valid.should be_false
      results.values.first.errors.first.message.should contain("Directory not found")
    end
  end

  describe ".summary" do
    it "generates a summary of validation results" do
      # Create mock results
      results = {} of String => AzuCLI::Validators::JinjaValidator::ValidationResult

      # Valid file
      valid_result = AzuCLI::Validators::JinjaValidator::ValidationResult.new
      results["valid.jinja"] = valid_result

      # File with errors
      error_result = AzuCLI::Validators::JinjaValidator::ValidationResult.new
      error_result.add_error(AzuCLI::Validators::JinjaValidator::ValidationError.new(1, 1, "Test error"))
      results["error.jinja"] = error_result

      # File with warnings
      warning_result = AzuCLI::Validators::JinjaValidator::ValidationResult.new
      warning_result.add_warning(AzuCLI::Validators::JinjaValidator::ValidationError.new(1, 1, "Test warning"))
      results["warning.jinja"] = warning_result

      summary = AzuCLI::Validators::JinjaValidator.summary(results)

      summary.should contain("Files processed: 3")
      summary.should contain("Valid files: 2")
      summary.should contain("Files with errors: 1")
      summary.should contain("Total errors: 1")
      summary.should contain("Total warnings: 1")
    end
  end

  describe "ValidationError" do
    it "formats error messages correctly" do
      error = AzuCLI::Validators::JinjaValidator::ValidationError.new(
        5, 10, "Test error", "Test suggestion"
      )

      error.to_s.should eq("Line 5, Column 10: Test error\n  Suggestion: Test suggestion")
    end

    it "formats error messages without suggestions" do
      error = AzuCLI::Validators::JinjaValidator::ValidationError.new(
        3, 7, "Test error"
      )

      error.to_s.should eq("Line 3, Column 7: Test error")
    end
  end

  describe "ValidationResult" do
    it "tracks errors and warnings" do
      result = AzuCLI::Validators::JinjaValidator::ValidationResult.new

      result.valid.should be_true

      error = AzuCLI::Validators::JinjaValidator::ValidationError.new(1, 1, "Error")
      result.add_error(error)

      result.valid.should be_false
      result.errors.size.should eq(1)

      warning = AzuCLI::Validators::JinjaValidator::ValidationError.new(2, 1, "Warning")
      result.add_warning(warning)

      result.warnings.size.should eq(1)
    end

    it "formats result messages correctly" do
      result = AzuCLI::Validators::JinjaValidator::ValidationResult.new

      error = AzuCLI::Validators::JinjaValidator::ValidationError.new(1, 1, "Test error", "Fix it")
      result.add_error(error)

      warning = AzuCLI::Validators::JinjaValidator::ValidationError.new(2, 1, "Test warning")
      result.add_warning(warning)

      message = result.to_s
      message.should contain("Errors:")
      message.should contain("Test error")
      message.should contain("Fix it")
      message.should contain("Warnings:")
      message.should contain("Test warning")
    end
  end
end
