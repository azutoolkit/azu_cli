require "../../spec_helper"
require "../../support/test_helpers"
require "../../support/generator_helpers"

private struct ScratchProject
  include GeneratorHelpers
end

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
      generator.crystal_type("date").should eq("Time") # Crystal has no Date
      generator.crystal_type("array").should eq("Array(String)")
      generator.crystal_type("hash").should eq("Hash(String, String)")
      generator.crystal_type("json").should eq("JSON::Any")
      generator.crystal_type("unknown").should eq("String")
    end
  end

  describe "#expiration_time" do
    it "turns the expiry into the Unix time in milliseconds JoobQ stores" do
      generator = AzuCLI::Generate::Job.new("Test")

      generator.expiration_time.should eq("1.days.from_now.to_unix_ms")

      generator = AzuCLI::Generate::Job.new("Test", expires: "30.minutes")
      generator.expiration_time.should eq("30.minutes.from_now.to_unix_ms")

      generator = AzuCLI::Generate::Job.new("Test", expires: "6.hours")
      generator.expiration_time.should eq("6.hours.from_now.to_unix_ms")

      generator = AzuCLI::Generate::Job.new("Test", expires: "7.days")
      generator.expiration_time.should eq("7.days.from_now.to_unix_ms")
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

      body.should contain("@data.each { |key, value| Log.info { \"\#{key}: \"+value.to_s } }")
    end
  end

  describe "validation" do
    it "refuses names that are not identifiers" do
      ["Foo\"} ; system(\"x\") #", "a/b", "../evil", "My Job", "1Job", "", "Foo;"].each do |name|
        expect_raises(ArgumentError, /Invalid job name/) { AzuCLI::Generate::Job.new(name) }
        AzuCLI::Generate::Job.error_for(name, {} of String => String).to_s.should contain("Invalid job name")
      end
    end

    it "refuses parameter names and types that are not identifiers" do
      expect_raises(ArgumentError, /Invalid parameter name/) { AzuCLI::Generate::Job.new("Email", {"x : String; y" => "String"}) }
      expect_raises(ArgumentError, /Invalid parameter name/) { AzuCLI::Generate::Job.new("Email", {"../x" => "String"}) }
      expect_raises(ArgumentError, /Invalid type/) { AzuCLI::Generate::Job.new("Email", {"x" => "String; system(\"x\")"}) }
      expect_raises(ArgumentError, /Invalid type/) { AzuCLI::Generate::Job.new("Email", {"x" => "Int32 y"}) }
    end

    it "refuses a queue that is not a plain name" do
      expect_raises(ArgumentError, /Invalid queue name/) { AzuCLI::Generate::Job.new("Email", {} of String => String, "q\"; x") }
    end

    it "refuses an expiry it does not understand instead of using one day" do
      expect_raises(ArgumentError, /Unsupported expiry/) { AzuCLI::Generate::Job.new("Email", {} of String => String, "default", 3, "soon") }
      expect_raises(ArgumentError, /Unsupported expiry/) { AzuCLI::Generate::Job.new("Email", {} of String => String, "default", 3, "1.day; x") }
    end

    it "accepts the documented forms" do
      AzuCLI::Generate::Job.new("Email", {"to" => "String", "note" => "String?"}, "mailers:high", 3, "1.month").file_path.should eq("src/jobs/email_job.cr")
    end

    it "is refused by azu generate job with a message, writing nothing" do
      ScratchProject.new.in_generated_project do
        command = AzuCLI::Commands::Generate.new
        command.parse_args(["job", "Foo\"} ; system(\"x\") #"])
        TestHelpers::TestSetup.with_captured_output do
          result = command.execute
          result.success?.should be_false
          result.error.should contain("Invalid job name")
        end
        Dir.exists?("src/jobs").should be_false

        command = AzuCLI::Commands::Generate.new
        command.parse_args(["job", "Email", "x;y:string"])
        TestHelpers::TestSetup.with_captured_output do
          result = command.execute
          result.success?.should be_false
          result.error.should contain("Invalid")
        end
        Dir.exists?("src/jobs").should be_false
      end
    end

    it "names the created file in azu generate job output, with or without the Job suffix" do
      %w(EmailJob Email).each do |name|
        ScratchProject.new.in_generated_project do
          command = AzuCLI::Commands::Generate.new
          command.parse_args(["job", name])
          TestHelpers::TestSetup.with_captured_output do |capture|
            command.execute.success?.should be_true
            capture.stdout.should contain("src/jobs/email_job.cr")
            capture.stdout.should_not contain("email_job_job.cr")
          end
          File.exists?("src/jobs/email_job.cr").should be_true
        end
      end
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

        job_file = File.join(temp_dir, "simple_job.cr")
        File.exists?(job_file).should be_true

        content = File.read(job_file)
        content.should contain("struct SimpleJob")
        content.should contain("include JoobQ::Job")
        content.should contain("@queue   = \"default\"")
        content.should contain("@retries = 3")
        content.should contain("@expires = 1.days.from_now.to_unix_ms")
        content.should contain("  def initialize\n")
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

        job_file = File.join(temp_dir, "email_job.cr")
        File.exists?(job_file).should be_true

        content = File.read(job_file)
        content.should contain("struct EmailJob")
        content.should contain("@queue   = \"emails\"")
        content.should contain("@retries = 5")
        content.should contain("@expires = 6.hours.from_now.to_unix_ms")
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

        job_file = File.join(temp_dir, "image_processing_job.cr")
        File.exists?(job_file).should be_true

        content = File.read(job_file)
        content.should contain("struct ImageProcessingJob")
        content.should contain("@queue   = \"images\"")
        content.should contain("@retries = 2")
        content.should contain("@expires = 30.minutes.from_now.to_unix_ms")
        content.should contain("@user_id : Int64, @image_path : String, @sizes : Array(String)")
        content.should contain("@sizes.each { |item| Log.info { \"Processing item: \"+item.to_s } }")
      ensure
        FileUtils.rm_rf(temp_dir)
      end
    end
  end

  describe "enhanced job generator testing" do
    describe "file generation with proper structure" do
      it "generates job files in correct directory" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_src_dir
          Dir.mkdir_p("src/jobs")

          generator = AzuCLI::Generate::Job.new("EmailJob")
          generator.render(AzuCLI::Generate::Job::OUTPUT_DIR)

          # Check that job file was created in correct location
          job_file = "src/jobs/email_job.cr"
          File.exists?(job_file).should be_true
        end
      end

      it "creates jobs directory if it doesn't exist" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_src_dir

          generator = AzuCLI::Generate::Job.new("EmailJob")
          generator.render(AzuCLI::Generate::Job::OUTPUT_DIR)

          # Check that directory was created
          Dir.exists?("src/jobs").should be_true

          # Check that file was created
          File.exists?("src/jobs/email_job.cr").should be_true
        end
      end

      it "handles nested job names correctly" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_src_dir
          Dir.mkdir_p("src/jobs")

          generator = AzuCLI::Generate::Job.new("UserNotificationJob")
          generator.render(AzuCLI::Generate::Job::OUTPUT_DIR)

          # Check that snake_case is used for filenames
          File.exists?("src/jobs/user_notification_job.cr").should be_true

          content = File.read("src/jobs/user_notification_job.cr")
          content.should contain("struct UserNotificationJob")
          File.exists?("src/jobs/user_notification_job_job.cr").should be_false
        end
      end

      it "names the file the same with or without the Job suffix" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_src_dir

          AzuCLI::Generate::Job.new("Email").render(AzuCLI::Generate::Job::OUTPUT_DIR)

          Dir.children("src/jobs").should eq(["email_job.cr"])
          File.read("src/jobs/email_job.cr").should contain("struct EmailJob")
        end
      end

      it "does not leave an empty argument list in the header examples of a job without parameters" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_src_dir

          AzuCLI::Generate::Job.new("Simple").render(AzuCLI::Generate::Job::OUTPUT_DIR)

          content = File.read("src/jobs/simple_job.cr")
          content.should contain("#   SimpleJob.enqueue\n")
          content.should contain("#   SimpleJob.delay(for: 5.minutes)\n")
        end
      end
    end

    describe "job configuration options" do
      it "generates job with custom queue" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_src_dir
          Dir.mkdir_p("src/jobs")

          generator = AzuCLI::Generate::Job.new("EmailJob", {} of String => String, "high_priority")
          generator.render(AzuCLI::Generate::Job::OUTPUT_DIR)

          job_file = "src/jobs/email_job.cr"
          content = File.read(job_file)

          content.should contain("@queue   = \"high_priority\"")
        end
      end

      it "generates job with custom retries" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_src_dir
          Dir.mkdir_p("src/jobs")

          generator = AzuCLI::Generate::Job.new("EmailJob", {} of String => String, "default", 5)
          generator.render(AzuCLI::Generate::Job::OUTPUT_DIR)

          job_file = "src/jobs/email_job.cr"
          content = File.read(job_file)

          content.should contain("@retries = 5")
        end
      end

      it "generates job with custom expiration" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_src_dir
          Dir.mkdir_p("src/jobs")

          generator = AzuCLI::Generate::Job.new("EmailJob", {} of String => String, "default", 3, "2.hours")
          generator.render(AzuCLI::Generate::Job::OUTPUT_DIR)

          job_file = "src/jobs/email_job.cr"
          content = File.read(job_file)

          content.should contain("@expires = 2.hours.from_now.to_unix_ms")
        end
      end
    end

    describe "job parameter handling" do
      it "handles complex parameter types" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_src_dir
          Dir.mkdir_p("src/jobs")

          parameters = {
            "user_id"    => "Int64",
            "email"      => "String",
            "data"       => "Hash",
            "tags"       => "Array",
            "created_at" => "Time",
          }

          generator = AzuCLI::Generate::Job.new("DataProcessingJob", parameters)
          generator.render(AzuCLI::Generate::Job::OUTPUT_DIR)

          job_file = "src/jobs/data_processing_job.cr"
          content = File.read(job_file)

          content.should contain("@user_id : Int64")
          content.should contain("@email : String")
          content.should contain("@data : Hash(String, String)")
          content.should contain("@tags : Array(String)")
          content.should contain("@created_at : Time")
          # a type with a comma is one declaration, and the header examples name each parameter once
          content.should contain("  property data : Hash(String, String)\n")
          content.should contain("#   DataProcessingJob.enqueue(user_id: value, email: value, data: value, tags: value, created_at: value)")
        end
      end

      it "handles optional parameters correctly" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_src_dir
          Dir.mkdir_p("src/jobs")

          parameters = {"user_id" => "Int64", "description" => "String?"}
          generator = AzuCLI::Generate::Job.new("OptionalJob", parameters)
          generator.render(AzuCLI::Generate::Job::OUTPUT_DIR)

          job_file = "src/jobs/optional_job.cr"
          content = File.read(job_file)

          content.should contain("@user_id : Int64")
          content.should contain("@description : String?")
        end
      end

      it "generates proper parameter list for job struct" do
        parameters = {"user_id" => "Int64", "email" => "String", "priority" => "Int32"}
        generator = AzuCLI::Generate::Job.new("TestJob", parameters)

        param_list = generator.constructor_params
        param_list.should contain("@user_id : Int64")
        param_list.should contain("@email : String")
        param_list.should contain("@priority : Int32")
      end
    end

    describe "job execution logic" do
      it "generates job with proper execution method" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_src_dir
          Dir.mkdir_p("src/jobs")

          generator = AzuCLI::Generate::Job.new("EmailJob")
          generator.render(AzuCLI::Generate::Job::OUTPUT_DIR)

          job_file = "src/jobs/email_job.cr"
          content = File.read(job_file)

          content.should contain("def perform")
          content.should contain("# Add your job logic here")
        end
      end

      it "generates job with error handling" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_src_dir
          Dir.mkdir_p("src/jobs")

          generator = AzuCLI::Generate::Job.new("EmailJob")
          generator.render(AzuCLI::Generate::Job::OUTPUT_DIR)

          job_file = "src/jobs/email_job.cr"
          content = File.read(job_file)

          content.should contain("rescue ex : Exception")
          content.should contain("Log.error")
        end
      end

      it "generates job with logging" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_src_dir
          Dir.mkdir_p("src/jobs")

          generator = AzuCLI::Generate::Job.new("EmailJob")
          generator.render(AzuCLI::Generate::Job::OUTPUT_DIR)

          job_file = "src/jobs/email_job.cr"
          content = File.read(job_file)

          content.should contain("Log.info")
          content.should contain("Log.error")
        end
      end
    end

    describe "job inheritance and includes" do
      it "includes proper JoobQ job inheritance" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_src_dir
          Dir.mkdir_p("src/jobs")

          generator = AzuCLI::Generate::Job.new("EmailJob")
          generator.render(AzuCLI::Generate::Job::OUTPUT_DIR)

          job_file = "src/jobs/email_job.cr"
          content = File.read(job_file)

          content.should contain("include JoobQ::Job")
          content.should contain("struct EmailJob")
        end
      end

      it "includes proper logging module" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_src_dir
          Dir.mkdir_p("src/jobs")

          generator = AzuCLI::Generate::Job.new("EmailJob")
          generator.render(AzuCLI::Generate::Job::OUTPUT_DIR)

          job_file = "src/jobs/email_job.cr"
          content = File.read(job_file)

          # the generated file relies on the application having loaded Log (azu and JoobQ do)
          content.should contain("Log.info")
          content.should contain("Log.error(exception: ex)")
        end
      end
    end

    describe "job scheduling and timing" do
      it "handles different expiration formats" do
        generator = AzuCLI::Generate::Job.new("TestJob")

        generator.expiration_time.should eq("1.days.from_now.to_unix_ms")
        # Test different expiration times by creating new generators
        generator_30min = AzuCLI::Generate::Job.new("TestJob", {} of String => String, "default", 3, "30.minutes")
        generator_30min.expiration_time.should eq("30.minutes.from_now.to_unix_ms")

        generator_1day = AzuCLI::Generate::Job.new("TestJob", {} of String => String, "default", 3, "1.day")
        generator_1day.expiration_time.should eq("1.days.from_now.to_unix_ms")

        generator_2hours = AzuCLI::Generate::Job.new("TestJob", {} of String => String, "default", 3, "2.hours")
        generator_2hours.expiration_time.should eq("2.hours.from_now.to_unix_ms")

        generator_2weeks = AzuCLI::Generate::Job.new("TestJob", {} of String => String, "default", 3, "2.weeks")
        generator_2weeks.expiration_time.should eq("2.weeks.from_now.to_unix_ms")
      end

      it "generates job with scheduling information" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_src_dir
          Dir.mkdir_p("src/jobs")

          generator = AzuCLI::Generate::Job.new("ScheduledJob", {} of String => String, "default", 3, "1.hour")
          generator.render(AzuCLI::Generate::Job::OUTPUT_DIR)

          job_file = "src/jobs/scheduled_job.cr"
          content = File.read(job_file)

          content.should contain("@queue   = \"default\"")
          content.should contain("@retries = 3")
          content.should contain("@expires = 1.hour.from_now.to_unix_ms")
        end
      end
    end

    describe "job testing support" do
      it "generates job with test-friendly structure" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_src_dir
          Dir.mkdir_p("src/jobs")

          generator = AzuCLI::Generate::Job.new("TestableJob")
          generator.render(AzuCLI::Generate::Job::OUTPUT_DIR)

          job_file = "src/jobs/testable_job.cr"
          content = File.read(job_file)

          content.should contain("struct TestableJob")
          content.should contain("def perform")
          content.should contain("include JoobQ::Job")
        end
      end

      it "generates job with proper initialization" do
        TestHelpers::TestSetup.with_temp_project do |temp_project|
          temp_project.create_shard_yml
          temp_project.create_src_dir
          Dir.mkdir_p("src/jobs")

          parameters = {"user_id" => "Int64", "email" => "String"}
          generator = AzuCLI::Generate::Job.new("TestableJob", parameters)
          generator.render(AzuCLI::Generate::Job::OUTPUT_DIR)

          job_file = "src/jobs/testable_job.cr"
          content = File.read(job_file)

          content.should contain("def initialize(@user_id : Int64, @email : String)")
        end
      end
    end
  end
end
