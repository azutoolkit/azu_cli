require "../../spec_helper"
require "teeplate"

describe AzuCLI::Generate::Mailer do
  it "creates a mailer generator with name" do
    generator = AzuCLI::Generate::Mailer.new("UserMailer")

    generator.name.should eq("UserMailer")
    generator.snake_case_name.should eq("user_mailer")
    generator.camel_case_name.should eq("UserMailer")
    generator.async.should be_true
  end

  it "creates a mailer generator with custom methods" do
    methods = ["welcome", "password_reset", "confirmation"]
    generator = AzuCLI::Generate::Mailer.new("UserMailer", methods)

    generator.methods.should eq(methods)
  end

  it "creates a mailer generator with async disabled" do
    generator = AzuCLI::Generate::Mailer.new("UserMailer", [] of String, false)

    generator.async.should be_false
  end

  it "uses default method when none provided" do
    generator = AzuCLI::Generate::Mailer.new("NotificationMailer")

    generator.methods.should eq(["welcome"])
  end

  it "converts name to snake_case" do
    generator = AzuCLI::Generate::Mailer.new("UserNotificationMailer")

    generator.snake_case_name.should eq("user_notification_mailer")
  end

  it "converts name to camelCase" do
    generator = AzuCLI::Generate::Mailer.new("user_mailer")

    generator.camel_case_name.should eq("UserMailer")
  end

  describe "#mailer_methods" do
    it "generates mailer method definitions" do
      generator = AzuCLI::Generate::Mailer.new("UserMailer", ["welcome"])

      methods = generator.mailer_methods
      methods.should contain("def welcome(to email : Carbon::Address")
      methods.should contain("Carbon::Email.new")
      methods.should contain("text_body")
      methods.should contain("html_body")
    end

    it "generates multiple mailer methods" do
      methods_list = ["welcome", "password_reset"]
      generator = AzuCLI::Generate::Mailer.new("UserMailer", methods_list)

      methods = generator.mailer_methods
      methods.should contain("def welcome")
      methods.should contain("def password_reset")
    end

    it "includes template paths" do
      generator = AzuCLI::Generate::Mailer.new("UserMailer", ["welcome"])

      methods = generator.mailer_methods
      methods.should contain("user_mailer/welcome")
    end
  end

  describe "#async_methods" do
    it "generates async delivery methods when enabled" do
      generator = AzuCLI::Generate::Mailer.new("UserMailer", ["welcome"], true)

      async = generator.async_methods
      async.should contain("def welcome_later")
      async.should contain("perform_later")
    end

    it "returns empty string when async is disabled" do
      generator = AzuCLI::Generate::Mailer.new("UserMailer", ["welcome"], false)

      async = generator.async_methods
      async.should be_empty
    end

    it "generates async methods for all mailer methods" do
      generator = AzuCLI::Generate::Mailer.new("UserMailer", ["welcome", "confirmation"])

      async = generator.async_methods
      async.should contain("def welcome_later")
      async.should contain("def confirmation_later")
    end
  end

  describe "#adapter_config" do
    it "generates Carbon adapter configuration" do
      generator = AzuCLI::Generate::Mailer.new("UserMailer")

      config = generator.adapter_config
      config.should contain("Carbon::DevAdapter")
      config.should contain("Carbon::SendGridAdapter")
      config.should contain("Carbon::SmtpAdapter")
    end
  end

  describe "#async_enabled?" do
    it "returns true when async is enabled" do
      generator = AzuCLI::Generate::Mailer.new("UserMailer", [] of String, true)

      generator.async_enabled?.should be_true
    end

    it "returns false when async is disabled" do
      generator = AzuCLI::Generate::Mailer.new("UserMailer", [] of String, false)

      generator.async_enabled?.should be_false
    end
  end

  describe "#template_names" do
    it "returns list of method names for templates" do
      methods = ["welcome", "confirmation", "password_reset"]
      generator = AzuCLI::Generate::Mailer.new("UserMailer", methods)

      generator.template_names.should eq(methods)
    end
  end

  describe "#dependencies" do
    it "returns carbon dependency" do
      generator = AzuCLI::Generate::Mailer.new("UserMailer")

      generator.dependencies.should eq("carbon")
    end
  end
end
