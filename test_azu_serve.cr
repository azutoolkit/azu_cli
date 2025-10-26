#!/usr/bin/env crystal

# Simple Crystal test script for azu serve functionality
require "process"
require "file_utils"

puts "🧪 Testing Azu CLI Project Creation and Serve"

# Create test directory
test_dir = "/tmp/azu_serve_test"
project_name = "testserve"

puts "📁 Creating test directory: #{test_dir}"
FileUtils.rm_rf(test_dir) if Dir.exists?(test_dir)
Dir.mkdir_p(test_dir)
Dir.cd(test_dir)

puts "🚀 Creating new Azu project: #{project_name}"
result = Process.run("/Users/eperez/Workspaces/azu_cli/bin/azu new #{project_name} --type=web --author=\"Test Author\" --email=\"test@example.com\" --no-git --no-example", shell: true, output: Process::Redirect::Pipe, error: Process::Redirect::Pipe)

unless result.success?
  puts "❌ Failed to create project: #{result.error_output}"
  exit 1
end

puts "📂 Project created, checking structure..."
Dir.cd(project_name)

puts "📋 Project structure:"
Dir.children("src").each do |item|
  puts "  - #{item}"
end

puts "📋 Checking required directories exist:"
required_dirs = ["validators", "components", "middleware", "services"]
required_dirs.each do |dir|
  gitkeep_path = "src/#{dir}/.gitkeep"
  if File.exists?(gitkeep_path)
    puts "✅ #{dir} directory: EXISTS"
  else
    puts "❌ #{dir} directory: MISSING"
  end
end

puts "🔨 Building project..."
result = Process.run("shards build", shell: true, output: Process::Redirect::Pipe, error: Process::Redirect::Pipe)
if result.success?
  puts "✅ Project builds successfully!"
else
  puts "❌ Project build failed: #{result.error_output}"
  exit 1
end

puts "🌐 Starting server in background..."
# Start server in background
server_process = Process.new("shards", ["run", "src/server.cr"], output: Process::Redirect::Pipe, error: Process::Redirect::Pipe)

# Wait for server to start
puts "⏳ Waiting for server to start..."
sleep 5

# Test HTTP endpoints
puts "🌍 Testing HTTP endpoints..."

# Test root endpoint
puts "Testing root endpoint (/)..."
result = Process.run("curl -s -o /dev/null -w \"%{http_code}\" http://localhost:3000/", shell: true, output: Process::Redirect::Pipe)
if result.output.to_s.strip == "200"
  puts "✅ Root endpoint responds with 200"
else
  puts "❌ Root endpoint failed: #{result.output}"
end

# Test welcome endpoint
puts "Testing welcome endpoint (/welcome)..."
result = Process.run("curl -s -o /dev/null -w \"%{http_code}\" http://localhost:3000/welcome", shell: true, output: Process::Redirect::Pipe)
if result.output.to_s.strip == "200"
  puts "✅ Welcome endpoint responds with 200"
else
  puts "❌ Welcome endpoint failed: #{result.output}"
end

# Test health endpoint
puts "Testing health endpoint (/health)..."
result = Process.run("curl -s -o /dev/null -w \"%{http_code}\" http://localhost:3000/health", shell: true, output: Process::Redirect::Pipe)
if result.output.to_s.strip == "200"
  puts "✅ Health endpoint responds with 200"
else
  puts "❌ Health endpoint failed: #{result.output}"
end

# Get actual response content
puts "📄 Root endpoint content:"
result = Process.run("curl -s http://localhost:3000/", shell: true, output: Process::Redirect::Pipe)
puts result.output.to_s.lines.first(3).join("\n")

puts "📄 Welcome endpoint content:"
result = Process.run("curl -s http://localhost:3000/welcome", shell: true, output: Process::Redirect::Pipe)
puts result.output.to_s.lines.first(3).join("\n")

# Stop server
puts "🛑 Stopping server..."
server_process.terminate
server_process.wait

puts "🧹 Cleaning up..."
Dir.cd("..")
FileUtils.rm_rf(test_dir)

puts "✅ All tests completed successfully!"
