require "../../spec_helper"
require "file_utils"

# Test directory for scaffold integration tests
SCAFFOLD_TEST_DIR = "./tmp/scaffold_test"

describe "Scaffold Integration" do
  # Setup and teardown
  before_each do
    Dir.mkdir_p(SCAFFOLD_TEST_DIR) unless Dir.exists?(SCAFFOLD_TEST_DIR)
    Dir.cd(SCAFFOLD_TEST_DIR) do
      # Create a basic shard.yml for the test project
      File.write("shard.yml", <<-YAML
      name: testapp
      version: 0.1.0
      dependencies:
        cql:
          github: azutoolkit/cql
        azu:
          github: azutoolkit/azu
      YAML
      )
    end
  end

  after_each do
    FileUtils.rm_rf(SCAFFOLD_TEST_DIR) if Dir.exists?(SCAFFOLD_TEST_DIR)
  end

  describe "Complete Scaffold Generation" do
    it "generates complete working scaffold with all components" do
      Dir.cd(SCAFFOLD_TEST_DIR) do
        # Generate scaffold
        generator_name = "Product"

        # Create the generate command
        command = AzuCLI::Commands::Generate.new
        command.parse_args(["--force", "scaffold", generator_name,
                            "name:string",
                            "description:text",
                            "price:float64",
                            "published:bool",
                            "--force"])

        # Execute scaffold generation
        result = command.execute
        result.success?.should be_true

        # Verify all expected files were created
        ScaffoldTestHelpers.verify_scaffold_files_exist(generator_name)
      end
    end

    it "generates endpoints with proper service integration" do
      Dir.cd(SCAFFOLD_TEST_DIR) do
        generator_name = "Article"

        command = AzuCLI::Commands::Generate.new
        command.parse_args(["--force", "scaffold", generator_name, "title:string", "content:text"])
        command.execute

        # Check endpoint files
        endpoint_files = Dir.glob("src/endpoints/articles/*_endpoint.cr")
        endpoint_files.size.should eq(7) # index, show, new, create, edit, update, destroy

        # Verify service calls in endpoints
        ScaffoldTestHelpers.verify_endpoint_service_calls(generator_name)
      end
    end

    it "generates services with correct signatures" do
      Dir.cd(SCAFFOLD_TEST_DIR) do
        generator_name = "Post"

        command = AzuCLI::Commands::Generate.new
        command.parse_args(["--force", "scaffold", generator_name, "title:string", "body:text"])
        command.execute

        # Verify service files exist
        service_files = Dir.glob("src/services/post/*_service.cr")
        service_files.size.should eq(5) # create, index, show, update, destroy

        # Check CreateService accepts request object
        create_service = File.read("src/services/post/create_service.cr")
        create_service.should contain("def call(request : Post::CreateRequest)")

        # Check UpdateService accepts ID and request object
        update_service = File.read("src/services/post/update_service.cr")
        update_service.should contain("def call(id : Int64, request : Post::UpdateRequest)")

        # Check ShowService accepts ID
        show_service = File.read("src/services/post/show_service.cr")
        show_service.should contain("def call(id :")

        # Check DestroyService accepts ID
        destroy_service = File.read("src/services/post/destroy_service.cr")
        destroy_service.should contain("def call(id :")
      end
    end
  end

  describe "Endpoint Service Wiring" do
    it "wires IndexEndpoint to IndexService correctly" do
      Dir.cd(SCAFFOLD_TEST_DIR) do
        command = AzuCLI::Commands::Generate.new
        command.parse_args(["--force", "scaffold", "Book", "title:string"])
        command.execute

        index_endpoint = File.read("src/endpoints/books/book_index_endpoint.cr")
        index_endpoint.should contain("IndexService.new.call")
        index_endpoint.should contain("result.success?")
        index_endpoint.should contain("result.data.not_nil!")
      end
    end

    it "wires ShowEndpoint to ShowService with ID" do
      Dir.cd(SCAFFOLD_TEST_DIR) do
        command = AzuCLI::Commands::Generate.new
        command.parse_args(["--force", "scaffold", "Book", "title:string"])
        command.execute

        show_endpoint = File.read("src/endpoints/books/book_show_endpoint.cr")
        show_endpoint.should contain("id = show_request.id")
        show_endpoint.should contain("ShowService.new.call(id)")
        show_endpoint.should contain("result.success?")
      end
    end

    it "wires CreateEndpoint to CreateService with request object" do
      Dir.cd(SCAFFOLD_TEST_DIR) do
        command = AzuCLI::Commands::Generate.new
        command.parse_args(["--force", "scaffold", "Book", "title:string"])
        command.execute

        create_endpoint = File.read("src/endpoints/books/book_create_endpoint.cr")
        create_endpoint.should contain("CreateService.new.call(create_request)")
        create_endpoint.should_not contain("create_request.title")
        create_endpoint.should contain("result.success?")
      end
    end

    it "wires UpdateEndpoint to UpdateService with ID and request" do
      Dir.cd(SCAFFOLD_TEST_DIR) do
        command = AzuCLI::Commands::Generate.new
        command.parse_args(["--force", "scaffold", "Book", "title:string"])
        command.execute

        update_endpoint = File.read("src/endpoints/books/book_update_endpoint.cr")
        update_endpoint.should contain("id = update_request.id")
        update_endpoint.should contain("UpdateService.new.call(id, update_request)")
        update_endpoint.should contain("result.success?")
      end
    end

    it "wires DestroyEndpoint to DestroyService with ID" do
      Dir.cd(SCAFFOLD_TEST_DIR) do
        command = AzuCLI::Commands::Generate.new
        command.parse_args(["--force", "scaffold", "Book", "title:string"])
        command.execute

        destroy_endpoint = File.read("src/endpoints/books/book_destroy_endpoint.cr")
        destroy_endpoint.should contain("id = destroy_request.id")
        destroy_endpoint.should contain("DestroyService.new.call(id)")
      end
    end

    it "wires EditEndpoint to ShowService to load data" do
      Dir.cd(SCAFFOLD_TEST_DIR) do
        command = AzuCLI::Commands::Generate.new
        command.parse_args(["--force", "scaffold", "Book", "title:string"])
        command.execute

        edit_endpoint = File.read("src/endpoints/books/book_edit_endpoint.cr")
        edit_endpoint.should contain("id = edit_request.id")
        edit_endpoint.should contain("ShowService.new.call(id)")
        edit_endpoint.should contain("result.success?")
      end
    end
  end

  describe "Redirect Functionality" do
    it "uses redirect to: syntax correctly in CreateEndpoint" do
      Dir.cd(SCAFFOLD_TEST_DIR) do
        command = AzuCLI::Commands::Generate.new
        command.parse_args(["--force", "scaffold", "Comment", "body:text"])
        command.execute

        create_endpoint = File.read("src/endpoints/comments/comment_create_endpoint.cr")
        create_endpoint.should contain("redirect to: \"/comments/\#{")
        create_endpoint.should contain("redirect to: \"/comments/new\"")
      end
    end

    it "uses redirect to: syntax in UpdateEndpoint" do
      Dir.cd(SCAFFOLD_TEST_DIR) do
        command = AzuCLI::Commands::Generate.new
        command.parse_args(["--force", "scaffold", "Comment", "body:text"])
        command.execute

        update_endpoint = File.read("src/endpoints/comments/comment_update_endpoint.cr")
        update_endpoint.should contain("redirect to: \"/comments/\#{")
        update_endpoint.should contain("/edit\"")
      end
    end

    it "uses redirect to: syntax in DestroyEndpoint" do
      Dir.cd(SCAFFOLD_TEST_DIR) do
        command = AzuCLI::Commands::Generate.new
        command.parse_args(["--force", "scaffold", "Comment", "body:text"])
        command.execute

        destroy_endpoint = File.read("src/endpoints/comments/comment_destroy_endpoint.cr")
        destroy_endpoint.should contain("redirect to: \"/comments\"")
      end
    end

    it "redirects to index on ShowEndpoint failure" do
      Dir.cd(SCAFFOLD_TEST_DIR) do
        command = AzuCLI::Commands::Generate.new
        command.parse_args(["--force", "scaffold", "Comment", "body:text"])
        command.execute

        show_endpoint = File.read("src/endpoints/comments/comment_show_endpoint.cr")
        show_endpoint.should contain("else")
        show_endpoint.should contain("redirect to: \"/comments\"")
      end
    end

    it "redirects to index on EditEndpoint failure" do
      Dir.cd(SCAFFOLD_TEST_DIR) do
        command = AzuCLI::Commands::Generate.new
        command.parse_args(["--force", "scaffold", "Comment", "body:text"])
        command.execute

        edit_endpoint = File.read("src/endpoints/comments/comment_edit_endpoint.cr")
        edit_endpoint.should contain("else")
        edit_endpoint.should contain("redirect to: \"/comments\"")
      end
    end
  end

  describe "Service Result Handling" do
    it "handles Services::Result success correctly" do
      Dir.cd(SCAFFOLD_TEST_DIR) do
        command = AzuCLI::Commands::Generate.new
        command.parse_args(["--force", "scaffold", "Task", "name:string"])
        command.execute

        create_endpoint = File.read("src/endpoints/tasks/task_create_endpoint.cr")
        create_endpoint.should contain("if result.success?")
        create_endpoint.should contain("result.data.not_nil!")
      end
    end

    it "handles Services::Result failure correctly" do
      Dir.cd(SCAFFOLD_TEST_DIR) do
        command = AzuCLI::Commands::Generate.new
        command.parse_args(["--force", "scaffold", "Task", "name:string"])
        command.execute

        create_endpoint = File.read("src/endpoints/tasks/task_create_endpoint.cr")
        create_endpoint.should contain("else")
        create_endpoint.should contain("redirect to:")
      end
    end

    it "services return Services::Result type" do
      Dir.cd(SCAFFOLD_TEST_DIR) do
        command = AzuCLI::Commands::Generate.new
        command.parse_args(["--force", "scaffold", "Task", "name:string"])
        command.execute

        create_service = File.read("src/services/task/create_service.cr")
        create_service.should contain("Services::Result(Task::Task)")
        create_service.should contain("Services::Result")
      end
    end
  end

  describe "Request Parameter Extraction" do
    it "includes id property in ShowRequest" do
      Dir.cd(SCAFFOLD_TEST_DIR) do
        command = AzuCLI::Commands::Generate.new
        command.parse_args(["--force", "scaffold", "User", "email:string"])
        command.execute

        show_request = File.read("src/requests/user/show_request.cr")
        show_request.should contain("property id : Int64")
      end
    end

    it "includes id property in EditRequest" do
      Dir.cd(SCAFFOLD_TEST_DIR) do
        command = AzuCLI::Commands::Generate.new
        command.parse_args(["--force", "scaffold", "User", "email:string"])
        command.execute

        edit_request = File.read("src/requests/user/edit_request.cr")
        edit_request.should contain("property id : Int64")
      end
    end

    it "includes id property in UpdateRequest" do
      Dir.cd(SCAFFOLD_TEST_DIR) do
        command = AzuCLI::Commands::Generate.new
        command.parse_args(["--force", "scaffold", "User", "email:string"])
        command.execute

        update_request = File.read("src/requests/user/update_request.cr")
        update_request.should contain("property id : Int64")
      end
    end

    it "includes id property in DestroyRequest" do
      Dir.cd(SCAFFOLD_TEST_DIR) do
        command = AzuCLI::Commands::Generate.new
        command.parse_args(["--force", "scaffold", "User", "email:string"])
        command.execute

        destroy_request = File.read("src/requests/user/destroy_request.cr")
        destroy_request.should contain("property id : Int64")
      end
    end

    it "includes field properties in CreateRequest" do
      Dir.cd(SCAFFOLD_TEST_DIR) do
        command = AzuCLI::Commands::Generate.new
        command.parse_args(["--force", "scaffold", "User", "email:string", "name:string"])
        command.execute

        create_request = File.read("src/requests/user/create_request.cr")
        create_request.should contain("property email")
        create_request.should contain("property name")
      end
    end
  end

  describe "HTTP Verb Mapping" do
    it "uses correct HTTP verbs in endpoints" do
      Dir.cd(SCAFFOLD_TEST_DIR) do
        command = AzuCLI::Commands::Generate.new
        command.parse_args(["--force", "scaffold", "Note", "content:text"])
        command.execute

        # GET for index
        File.read("src/endpoints/notes/note_index_endpoint.cr").should contain("get \"/notes\"")

        # GET for show
        File.read("src/endpoints/notes/note_show_endpoint.cr").should contain("get \"/notes/:id\"")

        # GET for new
        File.read("src/endpoints/notes/note_new_endpoint.cr").should contain("get \"/notes/new\"")

        # POST for create
        File.read("src/endpoints/notes/note_create_endpoint.cr").should contain("post \"/notes\"")

        # GET for edit
        File.read("src/endpoints/notes/note_edit_endpoint.cr").should contain("get \"/notes/:id/edit\"")

        # PATCH for update
        File.read("src/endpoints/notes/note_update_endpoint.cr").should contain("patch \"/notes/:id\"")

        # DELETE for destroy
        File.read("src/endpoints/notes/note_destroy_endpoint.cr").should contain("delete \"/notes/:id\"")
      end
    end
  end

  describe "Error Handling" do
    it "includes error handling in services" do
      Dir.cd(SCAFFOLD_TEST_DIR) do
        command = AzuCLI::Commands::Generate.new
        command.parse_args(["--force", "scaffold", "Item", "name:string"])
        command.execute

        create_service = File.read("src/services/item/create_service.cr")
        create_service.should contain("rescue ex")
        create_service.should contain("Log.error")

        show_service = File.read("src/services/item/show_service.cr")
        show_service.should contain("rescue CQL::RecordNotFound")
      end
    end

    it "includes logging in services" do
      Dir.cd(SCAFFOLD_TEST_DIR) do
        command = AzuCLI::Commands::Generate.new
        command.parse_args(["--force", "scaffold", "Item", "name:string"])
        command.execute

        create_service = File.read("src/services/item/create_service.cr")
        create_service.should contain("Log.info")
        create_service.should contain("Log.warn")
      end
    end
  end
end

# Helper methods for scaffold integration tests
module ScaffoldTestHelpers
  extend self

  def verify_scaffold_files_exist(resource_name)
    snake_case = resource_name.underscore
    plural = snake_case.pluralize

    # Model
    File.exists?("src/models/#{snake_case}.cr").should be_true

    # Migration
    Dir.glob("src/db/migrations/*_create_#{plural}.cr").size.should eq(1)

    # Endpoints
    %w[index show new create edit update destroy].each do |action|
      File.exists?("src/endpoints/#{plural}/#{snake_case}_#{action}_endpoint.cr").should be_true
    end

    # Services
    %w[create index show update destroy].each do |action|
      File.exists?("src/services/#{snake_case}/#{action}_service.cr").should be_true
    end

    # Result helper
    File.exists?("src/services/result.cr").should be_true

    # Requests
    %w[index show new create edit update destroy].each do |action|
      File.exists?("src/requests/#{snake_case}/#{action}_request.cr").should be_true
    end

    # Pages
    %w[index show new create edit update destroy].each do |action|
      File.exists?("src/pages/#{snake_case}/#{action}_page.cr").should be_true
    end
  end

  def verify_endpoint_service_calls(resource_name)
    snake_case = resource_name.underscore
    plural = snake_case.pluralize

    # Index calls IndexService
    index_endpoint = File.read("src/endpoints/#{plural}/#{snake_case}_index_endpoint.cr")
    index_endpoint.should contain("IndexService.new.call")

    # Show calls ShowService
    show_endpoint = File.read("src/endpoints/#{plural}/#{snake_case}_show_endpoint.cr")
    show_endpoint.should contain("ShowService.new.call(id)")

    # Create calls CreateService
    create_endpoint = File.read("src/endpoints/#{plural}/#{snake_case}_create_endpoint.cr")
    create_endpoint.should contain("CreateService.new.call(create_request)")

    # Update calls UpdateService
    update_endpoint = File.read("src/endpoints/#{plural}/#{snake_case}_update_endpoint.cr")
    update_endpoint.should contain("UpdateService.new.call(id, update_request)")

    # Destroy calls DestroyService
    destroy_endpoint = File.read("src/endpoints/#{plural}/#{snake_case}_destroy_endpoint.cr")
    destroy_endpoint.should contain("DestroyService.new.call(id)")

    # Edit calls ShowService to load data
    edit_endpoint = File.read("src/endpoints/#{plural}/#{snake_case}_edit_endpoint.cr")
    edit_endpoint.should contain("ShowService.new.call(id)")
  end
end
