require "file_utils"
require "process"
require "http/client"

module IntegrationHelpers
  # Create a temporary project and yield to the block
  def with_temp_project(name : String, type : String = "web", &block : String -> Nil)
    temp_dir = Dir.tempdir
    project_path = File.join(temp_dir, name)

    begin
      # Create the project
      Dir.mkdir_p(temp_dir)

      # Run azu new command
      cmd = ["bin/azu", "new", name, "--type", type, "--author", "Test Author", "--email", "test@example.com", "--no-git"]
      result = Process.run(cmd.join(" "), shell: true, chdir: temp_dir, output: Process::Redirect::Pipe, error: Process::Redirect::Pipe)

      unless result.success?
        raise "Failed to create project"
      end

      # Change to project directory and yield project path
      Dir.cd(project_path) do
        block.call(project_path)
      end
    ensure
      # Cleanup
      FileUtils.rm_rf(project_path) if Dir.exists?(project_path)
    end
  end

  # Build a project and return success/failure
  def build_project(path : String) : Bool
    result = Process.run("shards build", shell: true, chdir: path, output: Process::Redirect::Pipe, error: Process::Redirect::Pipe)
    result.success?
  end

  # Result wrapper to hold process status and output
  struct CommandResult
    property status : Process::Status
    property output : String
    property error : String

    def initialize(@status : Process::Status, @output : String, @error : String)
    end

    def success?
      @status.success?
    end
  end

  # Run a generator command
  def run_generator(command : String, project_path : String) : CommandResult
    full_command = "bin/azu #{command}"
    output = IO::Memory.new
    error = IO::Memory.new
    status = Process.run(full_command, shell: true, chdir: project_path, output: output, error: error)
    CommandResult.new(status, output.to_s, error.to_s)
  end

  # Start a server and yield to block, then stop it
  def with_running_server(project_path : String, port : Int32 = 4000, &block : Int32 -> Nil)
    # Build the project first
    unless build_project(project_path)
      raise "Failed to build project"
    end

    # Start server in background
    server_process = Process.new("shards", ["run", "src/server.cr"], chdir: project_path, output: Process::Redirect::Pipe, error: Process::Redirect::Pipe)

    # Wait for server to start
    sleep 2.milliseconds
    begin
      block.call(port)
    ensure
      # Stop server
      server_process.terminate
      server_process.wait
    end
  end

  # Make HTTP request to localhost
  def http_get(path : String, port : Int32 = 4000) : HTTP::Client::Response?
    client = HTTP::Client.new("localhost", port)
    begin
      client.get(path)
    rescue
      nil
    ensure
      client.close
    end
  end

  # Make HTTP POST request
  def http_post(path : String, body : String, port : Int32 = 4000) : HTTP::Client::Response?
    client = HTTP::Client.new("localhost", port)
    begin
      client.post(path, body: body, headers: HTTP::Headers{"Content-Type" => "application/json"})
    rescue
      nil
    ensure
      client.close
    end
  end

  # Check if a file exists in project
  def file_exists?(project_path : String, file_path : String) : Bool
    File.exists?(File.join(project_path, file_path))
  end

  # Read file content
  def read_file(project_path : String, file_path : String) : String?
    full_path = File.join(project_path, file_path)
    File.read(full_path) if File.exists?(full_path)
  end

  # Run crystal script and return output
  def run_crystal_script(project_path : String, script_content : String) : CommandResult
    script_path = File.join(project_path, "test_script.cr")
    File.write(script_path, script_content)

    output = IO::Memory.new
    error = IO::Memory.new
    status = Process.run("crystal", ["run", "test_script.cr"], chdir: project_path, output: output, error: error)

    File.delete(script_path) if File.exists?(script_path)
    CommandResult.new(status, output.to_s, error.to_s)
  end

  # Make HTTP GET request with authentication header
  def http_get_with_auth(path : String, token : String, port : Int32 = 4000) : HTTP::Client::Response?
    client = HTTP::Client.new("localhost", port)
    begin
      client.get(path, headers: HTTP::Headers{"Authorization" => "Bearer #{token}"})
    rescue
      nil
    ensure
      client.close
    end
  end

  # Make HTTP POST request with authentication header
  def http_post_with_auth(path : String, body : String, token : String, port : Int32 = 4000) : HTTP::Client::Response?
    client = HTTP::Client.new("localhost", port)
    begin
      client.post(path, body: body, headers: HTTP::Headers{
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{token}"
      })
    rescue
      nil
    ensure
      client.close
    end
  end

  # Make HTTP PUT request
  def http_put(path : String, body : String, port : Int32 = 4000) : HTTP::Client::Response?
    client = HTTP::Client.new("localhost", port)
    begin
      client.put(path, body: body, headers: HTTP::Headers{"Content-Type" => "application/json"})
    rescue
      nil
    ensure
      client.close
    end
  end

  # Make HTTP DELETE request
  def http_delete(path : String, port : Int32 = 4000) : HTTP::Client::Response?
    client = HTTP::Client.new("localhost", port)
    begin
      client.delete(path)
    rescue
      nil
    ensure
      client.close
    end
  end

  # Make HTTP DELETE request with authentication header
  def http_delete_with_auth(path : String, token : String, port : Int32 = 4000) : HTTP::Client::Response?
    client = HTTP::Client.new("localhost", port)
    begin
      client.delete(path, headers: HTTP::Headers{"Authorization" => "Bearer #{token}"})
    rescue
      nil
    ensure
      client.close
    end
  end
end
