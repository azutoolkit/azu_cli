require "teeplate"

module AzuCLI
  module Generate
    # Mailer generator for email functionality using Carbon
    # Carbon: https://github.com/luckyframework/carbon
    class Mailer < Teeplate::FileTree
      directory "#{__DIR__}/../templates/mailer"
      OUTPUT_DIR = "."

      property name : String
      property methods : Array(String)
      property snake_case_name : String
      property camel_case_name : String
      property async : Bool

      def initialize(@name : String, @methods : Array(String) = [] of String, @async : Bool = true)
        @snake_case_name = @name.underscore
        @camel_case_name = @name.camelcase
        @methods = ["welcome"] if @methods.empty?
      end

      # Generate mailer method definitions using Carbon
      def mailer_methods : String
        @methods.map do |method_name|
          <<-METHOD
              def #{method_name}(to email : Carbon::Address, params : Hash(String, String) = {} of String => String, **values) : Message
                data = params.dup
                values.each { |key, value| data[key.to_s] = value.to_s }
                Message.new(
                  to: [email],
                  from: Carbon::Address.new(from_name, from_email),
                  subject: "#{method_name.split("_").map(&.capitalize).join(" ")}",
                  text_body: render_text("#{@snake_case_name}/#{method_name}", data),
                  html_body: render_html("#{@snake_case_name}/#{method_name}", data)
                )
              end
          METHOD
        end.join("\n\n")
      end

      # Generate async delivery methods if enabled
      def async_methods : String
        if @async
          @methods.map do |method_name|
            <<-ASYNC
              # Deliver #{method_name} email asynchronously
              def #{method_name}_later(to email : Carbon::Address, params : Hash(String, String) = {} of String => String, **values)
                data = params.dup
                values.each { |key, value| data[key.to_s] = value.to_s }
                #{@camel_case_name}MailerJob.enqueue(
                  action: "#{method_name}",
                  to: email.address,
                  params: data
                )
              end
            ASYNC
          end.join("\n\n")
        else
          ""
        end
      end

      # Generate Carbon adapter configuration
      def adapter_config : String
        <<-CONFIG
          # Select a delivery adapter at the application composition root. Never silently
          # discard production mail through the development adapter.
          unless ENV["CRYSTAL_ENV"]? == "production"
            #{@camel_case_name}Mailer::Delivery.configure do |settings|
              settings.adapter = Carbon::DevAdapter.new
            end
          end
          # In production configure #{@camel_case_name}Mailer::Delivery with your
          # Carbon::SendGridAdapter or Carbon::SmtpAdapter (separate dependencies).
        CONFIG
      end

      # Teeplate renders these (it never calls a `filter`). Without async delivery (`--skip job`) nothing
      # enqueues the mailer job, so its file is not written.
      def rendered_file_entries
        file_entries.reject { |entry| !@async && entry.path.to_s.starts_with?("src/jobs/") }
      end

      # Check if async delivery is enabled
      def async_enabled? : Bool
        @async
      end

      # Get template names for generation
      def template_names : Array(String)
        @methods
      end

      # Get dependencies info
      def dependencies : String
        "carbon"
      end
    end
  end
end
