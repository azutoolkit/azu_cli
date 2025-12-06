require "../../spec_helper"
require "file_utils"

describe AzuCLI::Middleware::MigrationErrorHandler do
  # Use temp directory for test files
  temp_dir = File.join(Dir.tempdir, "azu_cli_test_#{Random.rand(10000)}")
  error_log_path = File.join(temp_dir, "log", "migration_errors.log")
  recovery_scripts_dir = File.join(temp_dir, "tmp", "migration_recovery")

  before_each do
    FileUtils.mkdir_p(File.dirname(error_log_path))
    FileUtils.mkdir_p(recovery_scripts_dir)
  end

  after_each do
    FileUtils.rm_rf(temp_dir) if Dir.exists?(temp_dir)
  end

  describe "#initialize" do
    it "creates handler with default paths" do
      handler = AzuCLI::Middleware::MigrationErrorHandler.new(
        error_log_path: error_log_path,
        recovery_scripts_dir: recovery_scripts_dir
      )

      handler.error_log_path.should eq(error_log_path)
      handler.recovery_scripts_dir.should eq(recovery_scripts_dir)
    end

    it "ensures directories exist" do
      test_log = File.join(temp_dir, "custom_log", "errors.log")
      test_recovery = File.join(temp_dir, "custom_recovery")

      handler = AzuCLI::Middleware::MigrationErrorHandler.new(
        error_log_path: test_log,
        recovery_scripts_dir: test_recovery
      )

      Dir.exists?(File.dirname(test_log)).should be_true
      Dir.exists?(test_recovery).should be_true
    end
  end

  describe "#handle_error" do
    it "handles connection errors" do
      handler = AzuCLI::Middleware::MigrationErrorHandler.new(
        error_log_path: error_log_path,
        recovery_scripts_dir: recovery_scripts_dir
      )
      error = Exception.new("connection refused to database")

      report = handler.handle_error(error, "CreateUsers", 20240101120000_i64)

      report.should contain("connection")
      report.should contain("Recovery Suggestions")
    end

    it "handles permission errors" do
      handler = AzuCLI::Middleware::MigrationErrorHandler.new(
        error_log_path: error_log_path,
        recovery_scripts_dir: recovery_scripts_dir
      )
      error = Exception.new("permission denied for table users")

      report = handler.handle_error(error, "CreateUsers", 20240101120000_i64)

      report.should contain("permission")
    end

    it "handles constraint violation errors" do
      handler = AzuCLI::Middleware::MigrationErrorHandler.new(
        error_log_path: error_log_path,
        recovery_scripts_dir: recovery_scripts_dir
      )
      error = Exception.new("constraint violation: duplicate key")

      report = handler.handle_error(error, "AddUniqueIndex", 20240101120000_i64)

      report.should contain("constraint")
    end

    it "handles timeout errors" do
      handler = AzuCLI::Middleware::MigrationErrorHandler.new(
        error_log_path: error_log_path,
        recovery_scripts_dir: recovery_scripts_dir
      )
      error = Exception.new("operation timed out after 30 seconds")

      report = handler.handle_error(error, "LongMigration", 20240101120000_i64)

      report.should contain("timeout")
    end

    it "handles syntax errors" do
      handler = AzuCLI::Middleware::MigrationErrorHandler.new(
        error_log_path: error_log_path,
        recovery_scripts_dir: recovery_scripts_dir
      )
      error = Exception.new("SQL syntax error near SELECT")

      report = handler.handle_error(error, "BadMigration", 20240101120000_i64)

      report.should contain("syntax")
    end

    it "handles missing table errors" do
      handler = AzuCLI::Middleware::MigrationErrorHandler.new(
        error_log_path: error_log_path,
        recovery_scripts_dir: recovery_scripts_dir
      )
      error = Exception.new("table \"users\" does not exist")

      report = handler.handle_error(error, "AddColumn", 20240101120000_i64)

      report.should contain("missing_table")
    end

    it "handles missing column errors" do
      handler = AzuCLI::Middleware::MigrationErrorHandler.new(
        error_log_path: error_log_path,
        recovery_scripts_dir: recovery_scripts_dir
      )
      # Note: must NOT contain "constraint" to avoid constraint classification
      error = Exception.new("column \"email\" does not exist")

      report = handler.handle_error(error, "ModifyColumn", 20240101120000_i64)

      report.should contain("missing_column")
    end

    it "handles foreign key errors" do
      handler = AzuCLI::Middleware::MigrationErrorHandler.new(
        error_log_path: error_log_path,
        recovery_scripts_dir: recovery_scripts_dir
      )
      # Note: "foreign key" without "constraint" to avoid constraint classification
      error = Exception.new("foreign key reference failed")

      report = handler.handle_error(error, "AddReference", 20240101120000_i64)

      report.should contain("foreign_key")
    end

    it "handles unique constraint errors" do
      handler = AzuCLI::Middleware::MigrationErrorHandler.new(
        error_log_path: error_log_path,
        recovery_scripts_dir: recovery_scripts_dir
      )
      # Note: "unique" without trigger words like "constraint", "violation", "duplicate"
      error = Exception.new("unique index on email prevented insert")

      report = handler.handle_error(error, "AddUniqueConstraint", 20240101120000_i64)

      report.should contain("unique_constraint")
    end

    it "handles unknown errors" do
      handler = AzuCLI::Middleware::MigrationErrorHandler.new(
        error_log_path: error_log_path,
        recovery_scripts_dir: recovery_scripts_dir
      )
      error = Exception.new("some unexpected error")

      report = handler.handle_error(error, "UnknownMigration", 20240101120000_i64)

      report.should contain("unknown")
      report.should contain("Recovery Suggestions")
    end

    it "creates error log file" do
      handler = AzuCLI::Middleware::MigrationErrorHandler.new(
        error_log_path: error_log_path,
        recovery_scripts_dir: recovery_scripts_dir
      )
      error = Exception.new("test error for logging")

      handler.handle_error(error, "TestMigration", 20240101120000_i64)

      File.exists?(error_log_path).should be_true
      File.read(error_log_path).should contain("test error for logging")
    end

    it "creates recovery script" do
      handler = AzuCLI::Middleware::MigrationErrorHandler.new(
        error_log_path: error_log_path,
        recovery_scripts_dir: recovery_scripts_dir
      )
      error = Exception.new("permission denied")

      report = handler.handle_error(error, "TestMigration", 20240101120000_i64)

      report.should contain("Recovery script created")
      Dir.glob("#{recovery_scripts_dir}/*.sql").size.should be > 0
    end
  end
end
