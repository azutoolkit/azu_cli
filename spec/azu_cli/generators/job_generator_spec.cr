require "../../spec_helper"

describe AzuCLI::Generate::Job do
  describe "#initialize" do
    it "creates a job generator with basic configuration" do
      generator = AzuCLI::Generate::Job.new("Email")

      generator.name.should eq("Email")
      generator.queue.should eq("default")
      generator.retries.should eq(3)
      generator.expires.should eq("1.days")
      generator.snake_case_name.should eq("email")
      generator.job_struct_name.should eq("EmailJob")
    end

    it "creates a job generator with custom configuration" do
      generator = AzuCLI::Generate::Job.new(
        "ImageProcessing",
        {"user_id" => "Int64", "image_path" => "String"},
        "images",
        2,
        "30.minutes"
      )

      generator.name.should eq("ImageProcessing")
      generator.queue.should eq("images")
      generator.retries.should eq(2)
      generator.expires.should eq("30.minutes")
      generator.snake_case_name.should eq("image_processing")
      generator.job_struct_name.should eq("ImageProcessingJob")
    end
  end

  describe "#crystal_type" do
    it "maps parameter types to Crystal types" do
      generator = AzuCLI::Generate::Job.new("Test")

      generator.crystal_type("string").should eq("String")
      generator.crystal_type("text").should eq("String")
      generator.crystal_type("int32").should eq("Int32")
      generator.crystal_type("integer").should eq("Int32")
      generator.crystal_type("int64").should eq("Int64")
      generator.crystal_type("float32").should eq("Float32")
      generator.crystal_type("float64").should eq("Float64")
      generator.crystal_type("float").should eq("Float64")
      generator.crystal_type("bool").should eq("Bool")
      generator.crystal_type("boolean").should eq("Bool")
      generator.crystal_type("time").should eq("Time")
      generator.crystal_type("datetime").should eq("Time")
      generator.crystal_type("date").should eq("Date")
      generator.crystal_type("array").should eq("Array(String)")
      generator.crystal_type("hash").should eq("Hash(String, String)")
      generator.crystal_type("json").should eq("JSON::Any")
      generator.crystal_type("unknown").should eq("String")
    end
  end

  describe "#expiration_seconds" do
    it "converts expiration times to seconds" do
      generator = AzuCLI::Generate::Job.new("Test")

      generator.expiration_seconds.should eq("1.days.total_seconds.to_i")

      generator = AzuCLI::Generate::Job.new("Test", expires: "30.minutes")
      generator.expiration_seconds.should eq("30.minutes.total_seconds.to_i")

      generator = AzuCLI::Generate::Job.new("Test", expires: "6.hours")
      generator.expiration_seconds.should eq("6.hours.total_seconds.to_i")

      generator = AzuCLI::Generate::Job.new("Test", expires: "7.days")
      generator.expiration_seconds.should eq("7.days.total_seconds.to_i")
    end
  end

  describe "#constructor_params" do
    it "generates constructor parameters string" do
      parameters = {
        "email_address" => "String",
        "subject"       => "String",
        "body"          => "String",
      }
      generator = AzuCLI::Generate::Job.new("Email", parameters)

      expected = "@email_address : String, @subject : String, @body : String"
      generator.constructor_params.should eq(expected)
    end

    it "handles mixed parameter types" do
      parameters = {
        "user_id"    => "Int64",
        "image_path" => "String",
        "sizes"      => "Array",
      }
      generator = AzuCLI::Generate::Job.new("ImageProcessing", parameters)

      expected = "@user_id : Int64, @image_path : String, @sizes : Array(String)"
      generator.constructor_params.should eq(expected)
    end

    it "returns empty string for no parameters" do
      generator = AzuCLI::Generate::Job.new("Simple")
      generator.constructor_params.should eq("")
    end
  end

  describe "#has_parameters?" do
    it "returns true when job has parameters" do
      parameters = {"email" => "String"}
      generator = AzuCLI::Generate::Job.new("Email", parameters)
      generator.has_parameters?.should be_true
    end

    it "returns false when job has no parameters" do
      generator = AzuCLI::Generate::Job.new("Simple")
      generator.has_parameters?.should be_false
    end
  end

  describe "#perform_method_body" do
    it "generates basic perform method for job without parameters" do
      generator = AzuCLI::Generate::Job.new("Simple")
      body = generator.perform_method_body

      body.should contain("TODO: Implement job logic here")
      body.should contain("Processing Simple job")
      body.should contain("Simple job completed successfully")
    end

    it "generates perform method with parameter examples" do
      parameters = {
        "email_address" => "String",
        "subject"       => "String",
      }
      generator = AzuCLI::Generate::Job.new("Email", parameters)
      body = generator.perform_method_body

      body.should contain("Log.info { \"Processing email_address: \"+@email_address.to_s }")
      body.should contain("Log.info { \"Processing subject: \"+@subject.to_s }")
      body.should contain("Email job completed successfully")
    end

    it "generates perform method with array parameter examples" do
      parameters = {"sizes" => "Array"}
      generator = AzuCLI::Generate::Job.new("ImageProcessing", parameters)
      body = generator.perform_method_body

      body.should contain("@sizes.each { |item| Log.info { \"Processing item: \"+item.to_s } }")
    end

    it "generates perform method with hash parameter examples" do
      parameters = {"data" => "Hash"}
      generator = AzuCLI::Generate::Job.new("Notification", parameters)
      body = generator.perform_method_body

      body.should contain("@data.each { |key, value| Log.info { \" {key}: \"+value.to_s } }")
    end
  end

  describe "#error_handling_example" do
    it "generates error handling code" do
      generator = AzuCLI::Generate::Job.new("Email")
      error_handling = generator.error_handling_example

      error_handling.should contain("rescue ex")
      error_handling.should contain("Log.error(exception: ex)")
      error_handling.should contain("Failed to process Email job")
      error_handling.should contain("raise ex")
    end
  end

  describe "template rendering" do
    it "generates a simple job without parameters" do
      generator = AzuCLI::Generate::Job.new("Simple")

      # Create temporary directory for testing
      temp_dir = File.join(Dir.tempdir, "job_generator_test_#{Random::Secure.hex(8)}")
      Dir.mkdir_p(temp_dir)
      begin
        generator.render(temp_dir)

        puts "Files in temp_dir:"
        Dir.glob(File.join(temp_dir, "**", "*")) { |f| puts f }

        job_file = File.join(temp_dir, "simple_job.cr")
        File.exists?(job_file).should be_true

        content = File.read(job_file)
        content.should contain("struct SimpleJob")
        content.should contain("include JoobQ::Job")
        content.should contain("@queue   = \"default\"")
        content.should contain("@retries = 3")
        content.should contain("@expires = 1.days.total_seconds.to_i")
        content.should contain("def initialize()")
        content.should contain("def perform")
        content.should contain("rescue ex")
      ensure
        FileUtils.rm_rf(temp_dir)
      end
    end

    it "generates a job with parameters" do
      parameters = {
        "email_address" => "String",
        "subject"       => "String",
        "body"          => "String",
      }
      generator = AzuCLI::Generate::Job.new("Email", parameters, "emails", 5, "6.hours")

      temp_dir = File.join(Dir.tempdir, "job_generator_test_#{Random::Secure.hex(8)}")
      Dir.mkdir_p(temp_dir)
      begin
        generator.render(temp_dir)

        puts "Files in temp_dir:"
        Dir.glob(File.join(temp_dir, "**", "*")) { |f| puts f }

        job_file = File.join(temp_dir, "email_job.cr")
        File.exists?(job_file).should be_true

        content = File.read(job_file)
        content.should contain("struct EmailJob")
        content.should contain("@queue   = \"emails\"")
        content.should contain("@retries = 5")
        content.should contain("@expires = 6.hours.total_seconds.to_i")
        content.should contain("@email_address : String, @subject : String, @body : String")
        content.should contain("Log.info { \"Processing email_address: \"+@email_address.to_s }")
        content.should contain("Log.info { \"Processing subject: \"+@subject.to_s }")
        content.should contain("Log.info { \"Processing body: \"+@body.to_s }")
      ensure
        FileUtils.rm_rf(temp_dir)
      end
    end

    it "generates a job with complex parameters" do
      parameters = {
        "user_id"    => "Int64",
        "image_path" => "String",
        "sizes"      => "Array",
      }
      generator = AzuCLI::Generate::Job.new("ImageProcessing", parameters, "images", 2, "30.minutes")

      temp_dir = File.join(Dir.tempdir, "job_generator_test_#{Random::Secure.hex(8)}")
      Dir.mkdir_p(temp_dir)
      begin
        generator.render(temp_dir)

        puts "Files in temp_dir:"
        Dir.glob(File.join(temp_dir, "**", "*")) { |f| puts f }

        job_file = File.join(temp_dir, "image_processing_job.cr")
        File.exists?(job_file).should be_true

        content = File.read(job_file)
        content.should contain("struct ImageProcessingJob")
        content.should contain("@queue   = \"images\"")
        content.should contain("@retries = 2")
        content.should contain("@expires = 30.minutes.total_seconds.to_i")
        content.should contain("@user_id : Int64, @image_path : String, @sizes : Array(String)")
        content.should contain("@sizes.each { |item| Log.info { \"Processing item: \"+item.to_s } }")
      ensure
        FileUtils.rm_rf(temp_dir)
      end
    end
  end
end
