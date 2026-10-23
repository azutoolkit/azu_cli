require "teeplate"

module AzuCLI
  module Generate
    # Job generator that creates JoobQ::Job structs
    # Generates background job classes with modern JoobQ API support
    class Job < Teeplate::FileTree
      directory "#{__DIR__}/../templates/scaffold/src/jobs"
      OUTPUT_DIR = "./src/jobs"

      property name : String
      property parameters : Hash(String, String)
      property queue : String
      property retries : Int32
      property expires : String
      property snake_case_name : String

      def initialize(@name : String, @parameters : Hash(String, String) = {} of String => String, @queue : String = "default", @retries : Int32 = 3, @expires : String = "1.days")
        @snake_case_name = file_base_name(@name)
      end

      # The file name stem: "EmailJob" and "Email" both give "email", the template adds the "_job" suffix
      private def file_base_name(name : String) : String
        stem = name.underscore.sub(/_job\z/, "")
        stem.empty? ? name.underscore : stem
      end

      # Convert name to job struct name
      def job_struct_name : String
        # Ensure Job suffix is added if not present
        name_str = @name.camelcase
        name_str.ends_with?("Job") ? name_str : name_str + "Job"
      end

      # Get constructor parameters
      def constructor_params : String
        @parameters.map { |name, type| "@#{name} : #{crystal_type(type)}" }.join(", ")
      end

      # `property name : Type` lines (a type such as Hash(String, String) contains a comma, so these are
      # built from the parameters rather than split out of #constructor_params)
      def property_declarations : Array(String)
        @parameters.map { |name, type| "property #{name} : #{crystal_type(type)}" }
      end

      # `name: value` pairs for the enqueue/schedule examples in the file header
      def example_arguments : String
        @parameters.keys.map { |name| "#{name}: value" }.join(", ")
      end

      # Get Crystal type for parameter; a trailing "?" makes it nilable
      def crystal_type(param_type : String) : String
        return crystal_type(param_type.rchop('?')) + "?" if param_type.ends_with?('?')

        case param_type.downcase
        when "string", "text"
          "String"
        when "int32", "integer"
          "Int32"
        when "int64"
          "Int64"
        when "float32"
          "Float32"
        when "float64", "float"
          "Float64"
        when "bool", "boolean"
          "Bool"
        when "time", "datetime"
          "Time"
        when "date"
          "Date"
        when "array"
          "Array(String)"
        when "hash"
          "Hash(String, String)"
        when "json"
          "JSON::Any"
        else
          "String"
        end
      end

      # Get expiration time in seconds
      def expiration_seconds : String
        case @expires.downcase
        when "30.minutes"
          "30.minutes.total_seconds.to_i"
        when "1.hour", "1.hours"
          "1.hour.total_seconds.to_i"
        when "6.hours"
          "6.hours.total_seconds.to_i"
        when "1.day", "1.days"
          "1.days.total_seconds.to_i"
        when "7.days", "1.week"
          "7.days.total_seconds.to_i"
        when "30.days", "1.month"
          "30.days.total_seconds.to_i"
        when /\A(\d+)\.(minute|hour|day|week)s?\z/
          "#{$1}.#{$2}s.total_seconds.to_i"
        else
          "1.days.total_seconds.to_i"
        end
      end

      # Get perform method body based on job type
      def perform_method_body : String
        if @parameters.empty?
          <<-PERFORM
              Log.info { "Processing #{@name} job" }

              begin
                # TODO: Implement job logic here
                # Add your job logic here
                # Example:
                # - Send emails
                # - Process data
                # - Call external APIs
                # - Generate reports

                Log.info { "#{@name} job completed successfully" }
              rescue ex
                Log.error(exception: ex) { "Failed to process #{@name} job" }
                raise ex # Let JoobQ handle retries
              end
          PERFORM
        else
          # Generate example usage of parameters
          param_examples = [] of String
          @parameters.each do |name, type|
            ivar = "@" + name
            case type.downcase
            when "string", "text"
              param_examples << %Q(Log.info { "Processing #{name}: "+#{ivar}.to_s })
            when "int32", "int64", "integer"
              param_examples << %Q(Log.info { "Processing #{name}: "+#{ivar}.to_s })
            when "array"
              param_examples << %Q(#{ivar}.each { |item| Log.info { "Processing item: "+item.to_s } })
            when "hash"
              param_examples << %Q(#{ivar}.each { |key, value| Log.info { " {key}: "+value.to_s } })
            else
              param_examples << %Q(Log.info { "Processing #{name}: "+#{ivar}.to_s })
            end
          end

          <<-PERFORM
              Log.info { "Starting #{@name} job with parameters" }

              begin
                # Log parameter values for debugging
                #{param_examples.join("\n    ")}

                # Add your job logic here
                # Example:
                # - Process the parameters
                # - Send emails to users
                # - Process data based on parameters
                # - Call external APIs with parameters

                Log.info { "#{@name} job completed successfully" }
              rescue ex
                Log.error(exception: ex) { "Failed to process #{@name} job" }
                raise ex # Let JoobQ handle retries
              end
          PERFORM
        end
      end

      # Check if job has parameters
      def has_parameters? : Bool
        !@parameters.empty?
      end

      # Get error handling example
      def error_handling_example : String
        <<-ERROR_HANDLING
          rescue ex
            Log.error(exception: ex) { "Failed to process #{@name} job" }
            raise ex # Let JoobQ handle retries
        ERROR_HANDLING
      end
    end
  end
end
