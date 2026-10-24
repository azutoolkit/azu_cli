require "json"

module AzuCLI
  module Diagnostics
    enum Status
      Ok
      Warn
      Fail

      def to_json(json : JSON::Builder) : Nil
        json.string(to_s.downcase)
      end
    end

    # The outcome of one diagnostic: what was checked (`id`), how it went, and what to do about it.
    struct Check
      include JSON::Serializable

      getter id : String
      getter status : Status
      getter message : String
      @[JSON::Field(emit_null: true)]
      getter hint : String?

      def initialize(@id : String, @status : Status, @message : String, @hint : String? = nil)
      end

      def self.ok(id : String, message : String) : Check
        new(id, Status::Ok, message)
      end

      def self.warn(id : String, message : String, hint : String) : Check
        new(id, Status::Warn, message, hint)
      end

      def self.fail(id : String, message : String, hint : String) : Check
        new(id, Status::Fail, message, hint)
      end

      # A problem is a warning, or a failure when `strict` (production).
      def self.problem(id : String, message : String, hint : String, strict : Bool) : Check
        strict ? fail(id, message, hint) : warn(id, message, hint)
      end
    end
  end
end
