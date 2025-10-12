require "teeplate"

module AzuCLI
  module Generate
    # Mailer generator for email functionality using Carbon
    # Carbon: https://github.com/luckyframework/carbon
    class Mailer < Teeplate::FileTree
      directory "#{__DIR__}/../templates/mailer"
      OUTPUT_DIR = "./src/mailers"

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
              def #{method_name}(to email : Carbon::Address, **params)
                #{method_name}_email(to: email, **params)
              end

              private def #{method_name}_email(to email : Carbon::Address, **params)
                Carbon::Email.new(
                  to: email,
                  from: Carbon::Address.new(from_email, from_name),
                  subject: "#{method_name.split("_").map(&.capitalize).join(" ")}",
                  text_body: render_text("#{@snake_case_name}/#{method_name}", params),
                  html_body: render_html("#{@snake_case_name}/#{method_name}", params)
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
              def #{method_name}_later(to email : Carbon::Address, **params)
                #{@camel_case_name}Job.perform_later(
                  action: "#{method_name}",
                  to: email.to_s,
                  params: params.to_h
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
          # Configure Carbon email adapter
          # Default: Development adapter (prints to console)
          # Production: Use SendGrid, SMTP, or custom adapter

          # Development: Print emails to console
          Carbon::DevAdapter.configure do |settings|
            settings.print_emails = true
          end

          # Production example (SendGrid):
          # Carbon::SendGridAdapter.configure do |settings|
          #   settings.api_key = ENV["SENDGRID_API_KEY"]
          # end

          # Production example (SMTP):
          # Carbon::SmtpAdapter.configure do |settings|
          #   settings.host = ENV["SMTP_HOST"]
          #   settings.port = ENV["SMTP_PORT"].to_i
          #   settings.username = ENV["SMTP_USERNAME"]
          #   settings.password = ENV["SMTP_PASSWORD"]
          # end
        CONFIG
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
