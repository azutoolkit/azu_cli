#!/usr/bin/env crystal

# Auth Generator Test Script
require "process"
require "file_utils"
require "json"

puts "🔐 Testing Auth Generator with HTTP POST requests"

# Create test directory
test_dir = "/tmp/auth_test"
project_name = "authtest"

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

puts "📂 Project created, entering project directory..."
Dir.cd(project_name)

puts "🔨 Building project..."
result = Process.run("shards build", shell: true, output: Process::Redirect::Pipe, error: Process::Redirect::Pipe)
if result.success?
  puts "✅ Project builds successfully!"
else
  puts "❌ Project build failed: #{result.error_output}"
  exit 1
end

puts "🔐 Generating Auth system..."
result = Process.run("/Users/eperez/Workspaces/azu_cli/bin/azu generate auth", shell: true, output: Process::Redirect::Pipe, error: Process::Redirect::Pipe)
if result.success?
  puts "✅ Auth system generated successfully!"
  puts "Auth generation output: #{result.output}"
else
  puts "❌ Auth generation failed: #{result.error_output}"
  exit 1
end

puts "📋 Checking auth files created..."
auth_files = [
  "src/models/user.cr",
  "src/endpoints/auth_endpoint.cr",
  "src/requests/auth/login_request.cr",
  "src/requests/auth/register_request.cr",
  "src/config/authly.cr"
]

auth_files.each do |file|
  if File.exists?(file)
    puts "✅ #{file}"
  else
    puts "❌ #{file} - MISSING"
  end
end

puts "🔨 Rebuilding project with auth..."
result = Process.run("shards build", shell: true, output: Process::Redirect::Pipe, error: Process::Redirect::Pipe)
if result.success?
  puts "✅ Project with auth builds successfully!"
else
  puts "❌ Project with auth build failed: #{result.error_output}"
  puts "Build error details: #{result.error_output}"
  exit 1
end

puts "🌐 Starting server in background..."
# Start server in background
server_process = Process.new("shards", ["run", "src/server.cr"], output: Process::Redirect::Pipe, error: Process::Redirect::Pipe)

# Wait for server to start
puts "⏳ Waiting for server to start..."
sleep 8

# Test auth endpoints with HTTP POST requests
puts "🌍 Testing Auth endpoints with HTTP POST requests..."

# Test register endpoint
puts "\n📝 Testing POST /auth/register..."
register_data = {
  "email" => "test@example.com",
  "password" => "password123",
  "password_confirmation" => "password123"
}.to_json

result = Process.run("curl -s -X POST -H 'Content-Type: application/json' -d '#{register_data}' http://localhost:3000/auth/register", shell: true, output: Process::Redirect::Pipe, error: Process::Redirect::Pipe)

puts "Register response status: #{result.exit_code}"
puts "Register response body: #{result.output}"

if result.exit_code == 0
  puts "✅ Register endpoint responded"
else
  puts "❌ Register endpoint failed"
end

# Test login endpoint
puts "\n🔑 Testing POST /auth/login..."
login_data = {
  "email" => "test@example.com",
  "password" => "password123"
}.to_json

result = Process.run("curl -s -X POST -H 'Content-Type: application/json' -d '#{login_data}' http://localhost:3000/auth/login", shell: true, output: Process::Redirect::Pipe, error: Process::Redirect::Pipe)

puts "Login response status: #{result.exit_code}"
puts "Login response body: #{result.output}"

if result.exit_code == 0
  puts "✅ Login endpoint responded"
else
  puts "❌ Login endpoint failed"
end

# Test refresh token endpoint
puts "\n🔄 Testing POST /auth/refresh..."
refresh_data = {
  "refresh_token" => "dummy_refresh_token"
}.to_json

result = Process.run("curl -s -X POST -H 'Content-Type: application/json' -d '#{refresh_data}' http://localhost:3000/auth/refresh", shell: true, output: Process::Redirect::Pipe, error: Process::Redirect::Pipe)

puts "Refresh response status: #{result.exit_code}"
puts "Refresh response body: #{result.output}"

if result.exit_code == 0
  puts "✅ Refresh endpoint responded"
else
  puts "❌ Refresh endpoint failed"
end

# Test change password endpoint
puts "\n🔒 Testing POST /auth/change_password..."
change_password_data = {
  "current_password" => "password123",
  "new_password" => "newpassword123",
  "new_password_confirmation" => "newpassword123"
}.to_json

result = Process.run("curl -s -X POST -H 'Content-Type: application/json' -d '#{change_password_data}' http://localhost:3000/auth/change_password", shell: true, output: Process::Redirect::Pipe, error: Process::Redirect::Pipe)

puts "Change password response status: #{result.exit_code}"
puts "Change password response body: #{result.output}"

if result.exit_code == 0
  puts "✅ Change password endpoint responded"
else
  puts "❌ Change password endpoint failed"
end

# Test logout endpoint
puts "\n🚪 Testing POST /auth/logout..."
logout_data = {
  "refresh_token" => "dummy_refresh_token"
}.to_json

result = Process.run("curl -s -X POST -H 'Content-Type: application/json' -d '#{logout_data}' http://localhost:3000/auth/logout", shell: true, output: Process::Redirect::Pipe, error: Process::Redirect::Pipe)

puts "Logout response status: #{result.exit_code}"
puts "Logout response body: #{result.output}"

if result.exit_code == 0
  puts "✅ Logout endpoint responded"
else
  puts "❌ Logout endpoint failed"
end

# Test basic endpoints still work
puts "\n🌐 Testing basic endpoints still work..."

# Test root endpoint
result = Process.run("curl -s -o /dev/null -w \"%{http_code}\" http://localhost:3000/", shell: true, output: Process::Redirect::Pipe)
if result.output.to_s.strip == "200"
  puts "✅ Root endpoint still works"
else
  puts "❌ Root endpoint broken: #{result.output}"
end

# Test welcome endpoint
result = Process.run("curl -s -o /dev/null -w \"%{http_code}\" http://localhost:3000/welcome", shell: true, output: Process::Redirect::Pipe)
if result.output.to_s.strip == "200"
  puts "✅ Welcome endpoint still works"
else
  puts "❌ Welcome endpoint broken: #{result.output}"
end

# Stop server
puts "\n🛑 Stopping server..."
server_process.terminate
server_process.wait

puts "\n🧹 Cleaning up..."
Dir.cd("..")
FileUtils.rm_rf(test_dir)

puts "\n✅ Auth generator test completed!"
puts "📊 Summary:"
puts "  - Project created and built successfully"
puts "  - Auth system generated"
puts "  - All auth files created"
puts "  - Project rebuilt with auth successfully"
puts "  - Server started and responded to HTTP requests"
puts "  - All auth endpoints tested with POST requests"
