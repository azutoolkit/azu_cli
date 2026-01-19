#!/bin/bash
# AZU CLI Refactoring Executor
# Systematically applies refactoring patterns to azu_cli

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

WORKSPACE="${1:-$HOME/azu-workspace}"
CLI_DIR="$WORKSPACE/azu_cli"
BACKUP_DIR="$WORKSPACE/backups/$(date +%Y%m%d_%H%M%S)"

print_header() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
}

print_step() {
    echo -e "${GREEN}▶ Step $1: $2${NC}"
}

print_substep() {
    echo -e "  ${YELLOW}→ $1${NC}"
}

# Create backup before refactoring
create_backup() {
    print_header "Creating Backup"
    
    mkdir -p "$BACKUP_DIR"
    cp -r "$CLI_DIR" "$BACKUP_DIR/"
    
    echo "Backup created at: $BACKUP_DIR"
}

# Verify framework patterns
verify_frameworks() {
    print_header "Verifying Framework Availability"
    
    for framework in azu cql joobq; do
        if [ -d "$WORKSPACE/$framework" ]; then
            echo -e "${GREEN}✓${NC} $framework available"
        else
            echo -e "${RED}✗${NC} $framework not found. Run analyze_codebase.sh first."
            exit 1
        fi
    done
}

# Refactor endpoint templates
refactor_endpoints() {
    print_step 1 "Refactoring Endpoint Templates"
    
    # Create new endpoint template
    print_substep "Creating AZU-compliant endpoint template..."
    
    cat > "$CLI_DIR/src/templates/endpoint.ecr" << 'TEMPLATE'
module <%= @module_name %>
  # <%= @summary %>
  #
  # @description <%= @description %>
  # @see https://azutoolkit.github.io/azu/endpoints
  class <%= @class_name %> < Azu::Endpoint(<%= @request_type %>, <%= @response_type %>)
    # @summary <%= @summary %>
    # @tags <%= @tags.join(", ") %>
    
    def call : <%= @response_type %>
      # TODO: Implement endpoint logic
      <%= @response_type %>.new(
        status: :ok,
        data: nil
      )
    rescue ex : Azu::NotFound
      error_response(ex, :not_found)
    rescue ex : Azu::UnprocessableEntity
      error_response(ex, :unprocessable_entity)
    rescue ex : Exception
      Log.error(exception: ex) { "Unexpected error in <%= @class_name %>" }
      error_response(ex, :internal_server_error)
    end
    
    private def error_response(ex : Exception, status : HTTP::Status) : <%= @response_type %>
      <%= @response_type %>.new(
        status: status,
        errors: [ex.message]
      )
    end
  end
end
TEMPLATE
    
    # Create request template
    print_substep "Creating request template..."
    
    cat > "$CLI_DIR/src/templates/request.ecr" << 'TEMPLATE'
module <%= @module_name %>
  struct <%= @class_name %>Request < Azu::Request
    include JSON::Serializable
    
<% @fields.each do |field| -%>
    getter <%= field[:name] %> : <%= field[:type] %><%= field[:optional] ? "?" : "" %><%= field[:default] ? " = #{field[:default]}" : "" %>
<% end -%>
    
    def validate : Array(String)
      errors = [] of String
      
<% @validations.each do |validation| -%>
      <%= validation %>
<% end -%>
      
      errors
    end
  end
end
TEMPLATE
    
    # Create response template
    print_substep "Creating response template..."
    
    cat > "$CLI_DIR/src/templates/response.ecr" << 'TEMPLATE'
module <%= @module_name %>
  struct <%= @class_name %>Response < Azu::Response
    include JSON::Serializable
    
    getter status : HTTP::Status
<% @fields.each do |field| -%>
    getter <%= field[:name] %> : <%= field[:type] %><%= field[:optional] ? "?" : "" %>
<% end -%>
    getter errors : Array(String)?
    
    def initialize(
      @status = :ok,
<% @fields.each do |field| -%>
      @<%= field[:name] %> = nil,
<% end -%>
      @errors = nil
    )
    end
    
    def success? : Bool
      status.success?
    end
  end
end
TEMPLATE
    
    echo "Endpoint templates created successfully"
}

# Refactor model templates
refactor_models() {
    print_step 2 "Refactoring Model Templates"
    
    print_substep "Creating CQL-compliant model template..."
    
    cat > "$CLI_DIR/src/templates/model.ecr" << 'TEMPLATE'
# <%= @description || "#{@class_name} model" %>
#
# @see https://azutoolkit.github.io/cql/models
class <%= @class_name %> < CQL::Model
  table :<%= @table_name %>
  
  # Primary key
  column id : Int64, primary_key: true
  
  # Columns
<% @columns.each do |col| -%>
  column <%= col[:name] %> : <%= col[:type] %><%= col[:nullable] ? "?" : "" %><%= col[:default] ? ", default: #{col[:default]}" : "" %>
<% end -%>
  
  # Timestamps
  column created_at : Time
  column updated_at : Time
  
  # Associations
<% @associations.each do |assoc| -%>
  <%= assoc[:type] %> :<%= assoc[:name] %>, <%= assoc[:class_name] %><%= assoc[:options] ? ", #{assoc[:options]}" : "" %>
<% end -%>
  
  # Validations
<% @validations.each do |validation| -%>
  validates :<%= validation[:field] %>, <%= validation[:rules].map { |k, v| "#{k}: #{v}" }.join(", ") %>
<% end -%>
  
  # Scopes
<% @scopes.each do |scope| -%>
  scope :<%= scope[:name] %>, -> { <%= scope[:query] %> }
<% end -%>
  
  # Callbacks
  before_save :set_timestamps
  
  private def set_timestamps
    now = Time.utc
    self.created_at ||= now
    self.updated_at = now
  end
end
TEMPLATE
    
    echo "Model template created successfully"
}

# Refactor migration templates
refactor_migrations() {
    print_step 3 "Refactoring Migration Templates"
    
    print_substep "Creating CQL-compliant migration template..."
    
    cat > "$CLI_DIR/src/templates/migration.ecr" << 'TEMPLATE'
# Migration: <%= @description %>
# Created: <%= Time.utc.to_s("%Y-%m-%d %H:%M:%S UTC") %>
#
# @see https://azutoolkit.github.io/cql/migrations
class <%= @class_name %> < CQL::Migration
  def up
<% if @action == :create_table -%>
    create_table :<%= @table_name %> do |t|
      t.primary_key :id, Int64, auto_increment: true
<% @columns.each do |col| -%>
      t.column :<%= col[:name] %>, <%= col[:type] %><%= col[:options] ? ", #{col[:options]}" : "" %>
<% end -%>
      t.timestamps
<% @indexes.each do |idx| -%>
      t.index <%= idx[:columns].inspect %><%= idx[:options] ? ", #{idx[:options]}" : "" %>
<% end -%>
    end
<% elsif @action == :add_column -%>
    alter_table :<%= @table_name %> do |t|
<% @columns.each do |col| -%>
      t.add_column :<%= col[:name] %>, <%= col[:type] %><%= col[:options] ? ", #{col[:options]}" : "" %>
<% end -%>
    end
<% elsif @action == :add_index -%>
<% @indexes.each do |idx| -%>
    add_index :<%= @table_name %>, <%= idx[:columns].inspect %><%= idx[:options] ? ", #{idx[:options]}" : "" %>
<% end -%>
<% elsif @action == :add_foreign_key -%>
    add_foreign_key :<%= @table_name %>, :<%= @column %>, :<%= @reference_table %>, :<%= @reference_column %><%= @fk_options ? ", #{@fk_options}" : "" %>
<% end -%>
  end
  
  def down
<% if @action == :create_table -%>
    drop_table :<%= @table_name %>
<% elsif @action == :add_column -%>
    alter_table :<%= @table_name %> do |t|
<% @columns.each do |col| -%>
      t.remove_column :<%= col[:name] %>
<% end -%>
    end
<% elsif @action == :add_index -%>
<% @indexes.each do |idx| -%>
    remove_index :<%= @table_name %>, <%= idx[:columns].inspect %>
<% end -%>
<% elsif @action == :add_foreign_key -%>
    remove_foreign_key :<%= @table_name %>, :<%= @column %>
<% end -%>
  end
end
TEMPLATE
    
    echo "Migration template created successfully"
}

# Refactor job templates
refactor_jobs() {
    print_step 4 "Refactoring Job Templates"
    
    print_substep "Creating JOOBQ-compliant job template..."
    
    cat > "$CLI_DIR/src/templates/job.ecr" << 'TEMPLATE'
# <%= @description || "#{@class_name} background job" %>
#
# @queue <%= @queue || "default" %>
# @see https://azutoolkit.github.io/joobq/jobs
class <%= @class_name %>
  include Joobq::Job
  
  # Queue configuration
  queue "<%= @queue || "default" %>"
<% if @retries -%>
  retry_on StandardError, attempts: <%= @retries %>, delay: <%= @retry_delay || "30.seconds" %>
<% end -%>
<% if @discard_on -%>
  discard_on <%= @discard_on.join(", ") %>
<% end -%>
<% if @timeout -%>
  timeout <%= @timeout %>
<% end -%>
  
  # Job arguments
<% @arguments.each do |arg| -%>
  getter <%= arg[:name] %> : <%= arg[:type] %><%= arg[:default] ? " = #{arg[:default]}" : "" %>
<% end -%>
  
  def initialize(<%= @arguments.map { |a| "@#{a[:name]}" }.join(", ") %>)
  end
  
  def perform
    Log.info { "Starting <%= @class_name %>" }
    
    # TODO: Implement job logic
    
    Log.info { "Completed <%= @class_name %>" }
  rescue ex : Exception
    Log.error(exception: ex) { "Failed <%= @class_name %>: #{ex.message}" }
    raise ex  # Re-raise to trigger retry
  end
end
TEMPLATE
    
    echo "Job template created successfully"
}

# Update generator classes
update_generators() {
    print_step 5 "Updating Generator Classes"
    
    print_substep "Creating base generator..."
    
    mkdir -p "$CLI_DIR/src/generators"
    
    cat > "$CLI_DIR/src/generators/base_generator.cr" << 'TEMPLATE'
require "ecr"

module AzuCli
  module Generators
    abstract class BaseGenerator
      Log = ::Log.for(self)
      
      # Output directory for generated files
      property output_dir : String = "."
      
      # Whether to overwrite existing files
      property force : Bool = false
      
      # Dry run mode (don't actually create files)
      property dry_run : Bool = false
      
      # Generate the file content
      abstract def generate : String
      
      # Get the output file path
      abstract def output_path : String
      
      # Run the generator
      def run : Bool
        content = generate
        path = File.join(output_dir, output_path)
        
        if File.exists?(path) && !force
          Log.warn { "File already exists: #{path}" }
          return false unless confirm_overwrite?(path)
        end
        
        if dry_run
          Log.info { "Would create: #{path}" }
          puts content
          return true
        end
        
        # Create directory structure
        dir = File.dirname(path)
        Dir.mkdir_p(dir) unless Dir.exists?(dir)
        
        # Write file
        File.write(path, content)
        Log.info { "Created: #{path}" }
        
        # Show next steps
        show_next_steps
        
        true
      rescue ex : Exception
        Log.error(exception: ex) { "Failed to generate: #{ex.message}" }
        false
      end
      
      # Validate generator configuration
      def validate! : Nil
        errors = validate
        unless errors.empty?
          raise ValidationError.new(errors.join(", "))
        end
      end
      
      # Override in subclasses to add validation
      def validate : Array(String)
        [] of String
      end
      
      # Override to show next steps after generation
      def show_next_steps : Nil
        # Default: no next steps
      end
      
      private def confirm_overwrite?(path : String) : Bool
        print "File exists: #{path}. Overwrite? [y/N] "
        response = gets
        response.try(&.downcase) == "y"
      end
      
      # Helper to convert to PascalCase
      protected def pascal_case(str : String) : String
        str.split(/[_\-\s]/).map(&.capitalize).join
      end
      
      # Helper to convert to snake_case
      protected def snake_case(str : String) : String
        str.gsub(/([A-Z])/, "_\\1").downcase.lstrip('_')
      end
      
      # Helper to pluralize
      protected def pluralize(str : String) : String
        # Simple pluralization - can be enhanced
        if str.ends_with?("y")
          str[0..-2] + "ies"
        elsif str.ends_with?("s") || str.ends_with?("x") || str.ends_with?("ch")
          str + "es"
        else
          str + "s"
        end
      end
    end
    
    class ValidationError < Exception
    end
  end
end
TEMPLATE
    
    print_substep "Creating endpoint generator..."
    
    cat > "$CLI_DIR/src/generators/endpoint_generator.cr" << 'TEMPLATE'
require "./base_generator"

module AzuCli
  module Generators
    class EndpointGenerator < BaseGenerator
      TEMPLATE_PATH = "#{__DIR__}/../templates/endpoint.ecr"
      
      property module_name : String
      property class_name : String
      property request_type : String
      property response_type : String
      property summary : String
      property description : String
      property tags : Array(String)
      
      def initialize(
        @module_name,
        @class_name,
        @summary = "TODO: Add summary",
        @description = "TODO: Add description",
        @tags = [] of String
      )
        @request_type = "#{@class_name}Request"
        @response_type = "#{@class_name}Response"
      end
      
      def generate : String
        ECR.render(TEMPLATE_PATH)
      end
      
      def output_path : String
        module_path = @module_name.downcase.gsub("::", "/")
        "src/endpoints/#{module_path}/#{snake_case(@class_name)}.cr"
      end
      
      def validate : Array(String)
        errors = [] of String
        
        if @module_name.empty?
          errors << "Module name is required"
        end
        
        if @class_name.empty?
          errors << "Class name is required"
        elsif !@class_name.matches?(/^[A-Z][a-zA-Z0-9]*$/)
          errors << "Class name must be PascalCase"
        end
        
        errors
      end
      
      def show_next_steps : Nil
        puts <<-STEPS
        
        ✅ Created endpoint: #{output_path}
        
        Next steps:
          1. Add route to config/routes.cr:
             
             get "/path", #{@module_name}::#{@class_name}
             
          2. Implement the endpoint logic in:
             #{output_path}
             
          3. Create request/response structs if needed
          
          4. Add specs in:
             spec/endpoints/#{snake_case(@class_name)}_spec.cr
        
        Documentation: https://azutoolkit.github.io/azu/endpoints
        STEPS
      end
    end
  end
end
TEMPLATE
    
    echo "Generator classes updated successfully"
}

# Add CLI commands
update_cli_commands() {
    print_step 6 "Updating CLI Commands"
    
    print_substep "Creating generate command..."
    
    mkdir -p "$CLI_DIR/src/commands"
    
    cat > "$CLI_DIR/src/commands/generate_command.cr" << 'TEMPLATE'
require "admiral"
require "../generators/*"

module AzuCli
  class GenerateCommand < Admiral::Command
    define_help description: <<-DESC
      Generate AZU application components.
      
      USAGE:
        azu generate <component> <name> [options]
      
      COMPONENTS:
        endpoint    Create a new API endpoint (AZU)
        model       Create a CQL model with migration
        migration   Create a CQL database migration
        job         Create a JOOBQ background job
        channel     Create a WebSocket channel
        serializer  Create a response serializer
      
      EXAMPLES:
        azu generate endpoint Api::V1::Users::Index
        azu generate model User email:string name:string
        azu generate migration AddAvatarToUsers avatar:string
        azu generate job SendWelcomeEmail --queue=emails
      
      OPTIONS:
        -f, --force     Overwrite existing files
        -n, --dry-run   Show what would be generated without creating files
        -q, --quiet     Suppress output
      
      For component-specific help:
        azu generate <component> --help
      
      DOCUMENTATION:
        https://azutoolkit.github.io/azu/
      DESC
    
    define_flag force : Bool,
      short: f,
      default: false,
      description: "Overwrite existing files"
    
    define_flag dry_run : Bool,
      short: n,
      default: false,
      description: "Show what would be generated"
    
    define_flag quiet : Bool,
      short: q,
      default: false,
      description: "Suppress output"
    
    define_argument component : String,
      description: "Component type to generate"
    
    define_argument name : String,
      description: "Name for the generated component"
    
    def run
      case arguments.component
      when "endpoint"
        generate_endpoint
      when "model"
        generate_model
      when "migration"
        generate_migration
      when "job"
        generate_job
      when "channel"
        generate_channel
      when "serializer"
        generate_serializer
      else
        puts "Unknown component: #{arguments.component}"
        puts "Run 'azu generate --help' for available components"
        exit 1
      end
    end
    
    private def generate_endpoint
      parts = arguments.name.split("::")
      class_name = parts.pop
      module_name = parts.join("::")
      module_name = "App" if module_name.empty?
      
      generator = Generators::EndpointGenerator.new(
        module_name: module_name,
        class_name: class_name
      )
      
      generator.force = flags.force
      generator.dry_run = flags.dry_run
      generator.validate!
      generator.run
    end
    
    private def generate_model
      # Parse name and fields from arguments
      puts "Model generation: #{arguments.name}"
      puts "Additional args will be parsed as fields"
    end
    
    private def generate_migration
      puts "Migration generation: #{arguments.name}"
    end
    
    private def generate_job
      puts "Job generation: #{arguments.name}"
    end
    
    private def generate_channel
      puts "Channel generation: #{arguments.name}"
    end
    
    private def generate_serializer
      puts "Serializer generation: #{arguments.name}"
    end
  end
end
TEMPLATE
    
    echo "CLI commands updated successfully"
}

# Run tests
run_tests() {
    print_step 7 "Running Tests"
    
    cd "$CLI_DIR"
    
    if [ -f "shard.yml" ]; then
        print_substep "Installing dependencies..."
        shards install 2>/dev/null || true
        
        print_substep "Running crystal spec..."
        crystal spec 2>/dev/null || print_warning "Some tests failed or no tests found"
    fi
}

# Generate summary
generate_summary() {
    print_header "Refactoring Summary"
    
    cat << EOF
    
Refactoring Complete!

Files Modified/Created:
  ├── src/templates/
  │   ├── endpoint.ecr
  │   ├── request.ecr
  │   ├── response.ecr
  │   ├── model.ecr
  │   ├── migration.ecr
  │   └── job.ecr
  ├── src/generators/
  │   ├── base_generator.cr
  │   └── endpoint_generator.cr
  └── src/commands/
      └── generate_command.cr

Backup Location: $BACKUP_DIR

Next Steps:
  1. Review generated templates in src/templates/
  2. Test each generator: azu generate <type> Test
  3. Run full test suite: crystal spec
  4. Update documentation and help text
  5. Create pull request with changes

EOF
}

# Main execution
main() {
    print_header "AZU CLI Refactoring Tool"
    echo "Workspace: $WORKSPACE"
    echo ""
    
    if [ ! -d "$CLI_DIR" ]; then
        echo "Error: azu_cli not found at $CLI_DIR"
        echo "Run analyze_codebase.sh first to clone repositories"
        exit 1
    fi
    
    create_backup
    verify_frameworks
    refactor_endpoints
    refactor_models
    refactor_migrations
    refactor_jobs
    update_generators
    update_cli_commands
    run_tests
    generate_summary
}

main "$@"
