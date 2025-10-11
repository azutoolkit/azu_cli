require "./base"

module AzuCLI
  module Commands
    # Test command with watch mode and coverage
    class Test < Base
      property watch : Bool = false
      property coverage : Bool = false
      property verbose : Bool = false
      property parallel : Bool = false
      property filter : String?
      property file : String?

      def initialize
        super("test", "Run application tests")
      end

      def execute : Result
        parse_options

        if @watch
          run_with_watch
        else
          run_tests
        end
      rescue ex
        Logger.info("\n🛑 Test run interrupted")
        error("Test error: #{ex.message}")
      end

      private def parse_options
        args = get_args
        args.each_with_index do |arg, index|
          case arg
          when "--watch", "-w"
            @watch = true
          when "--coverage", "-c"
            @coverage = true
          when "--verbose", "-v"
            @verbose = true
          when "--parallel", "-p"
            @parallel = true
          when "--filter", "-f"
            @filter = args[index + 1]? if index + 1 < args.size
          else
            # Treat non-flag arguments as file paths
            unless arg.starts_with?("--") || arg.starts_with?("-")
              @file = arg
            end
          end
        end
      end

      private def run_tests : Result
        Logger.info("🧪 Running tests...")
        show_test_config

        args = build_test_args

        output = IO::Memory.new
        error = IO::Memory.new
        start_time = Time.monotonic

        status = Process.run(
          "crystal",
          args,
          output: output,
          error: error
        )

        duration = (Time.monotonic - start_time).total_seconds

        # Display output
        puts output.to_s unless output.empty?
        puts error.to_s unless error.empty?

        if status.success?
          Logger.info("✅ Tests passed in #{duration.round(2)}s")
          success("Tests passed")
        else
          Logger.error("❌ Tests failed")
          error("Tests failed")
        end
      end

      private def run_with_watch
        Logger.info("👀 Running tests in watch mode...")
        Logger.info("Press Ctrl+C to stop")
        puts ""

        # Run tests initially
        run_tests

        # Watch for file changes
        file_mtimes = {} of String => Time
        scan_files(file_mtimes)

        loop do
          sleep 0.5.seconds

          changed_files = detect_changes(file_mtimes)

          unless changed_files.empty?
            puts "\n" + "=" * 80
            Logger.info("📝 File changed: #{changed_files.first}")
            Logger.info("🔄 Re-running tests...")
            puts "=" * 80
            puts ""

            run_tests

            puts ""
          end
        end
      end

      private def show_test_config
        Logger.info("Watch mode: #{@watch ? "enabled" : "disabled"}")
        Logger.info("Coverage: #{@coverage ? "enabled" : "disabled"}")
        Logger.info("Parallel: #{@parallel ? "enabled" : "disabled"}")
        Logger.info("Filter: #{@filter || "none"}") if @filter
        Logger.info("File: #{@file}") if @file
        puts ""
      end

      private def build_test_args : Array(String)
        args = ["spec"]

        # Add file/directory to test
        if file = @file
          args << file
        end

        # Add filter
        if filter = @filter
          args << "--example" << filter
        end

        # Add verbose flag
        if @verbose
          args << "--verbose"
        end

        # Add parallel flag (Crystal doesn't have built-in parallel, but we can pass it through)
        if @parallel
          args << "--parallel"
        end

        # Add coverage (would require additional tooling)
        if @coverage
          Logger.warn("Coverage reporting requires additional setup")
          Logger.info("Consider using coverage tools like crystalcoverage")
        end

        args
      end

      private def scan_files(mtimes : Hash(String, Time))
        patterns = [
          "src/**/*.cr",
          "spec/**/*.cr",
        ]

        patterns.each do |pattern|
          Dir.glob(pattern).each do |file|
            next unless File.file?(file)
            mtimes[file] = File.info(file).modification_time
          end
        end
      rescue ex
        Logger.warn("Error scanning files: #{ex.message}") if @verbose
      end

      private def detect_changes(mtimes : Hash(String, Time)) : Array(String)
        changed = [] of String

        patterns = [
          "src/**/*.cr",
          "spec/**/*.cr",
        ]

        patterns.each do |pattern|
          Dir.glob(pattern).each do |file|
            next unless File.file?(file)

            current_mtime = File.info(file).modification_time

            if !mtimes.has_key?(file) || mtimes[file] != current_mtime
              changed << file
              mtimes[file] = current_mtime
            end
          end
        end

        # Check for deleted files
        mtimes.keys.each do |file|
          unless File.exists?(file)
            changed << file
            mtimes.delete(file)
          end
        end

        changed
      rescue ex
        Logger.warn("Error detecting changes: #{ex.message}") if @verbose
        [] of String
      end
    end
  end
end

