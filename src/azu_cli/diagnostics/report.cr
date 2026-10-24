require "json"
require "./check"

module AzuCLI
  module Diagnostics
    # The checks and their rendering.
    class Report
      getter checks : Array(Check)

      def initialize(@checks : Array(Check))
      end

      def count(status : Status) : Int32
        checks.count { |check| check.status == status }
      end

      def failed? : Bool
        count(Status::Fail) > 0
      end

      def summary : String
        "#{count(Status::Ok)} ok, #{count(Status::Warn)} warnings, #{count(Status::Fail)} failures"
      end

      def to_json : String
        JSON.build(indent: 2) do |json|
          json.object do
            json.field "checks", checks
            json.field "summary" do
              json.object do
                Status.each { |status| json.field status.to_s.downcase, count(status) }
              end
            end
          end
        end
      end

      def to_text : String
        width = checks.max_of?(&.id.size) || 0
        String.build do |io|
          checks.each do |check|
            io << check.status.to_s.downcase.ljust(4) << "  " << check.id.ljust(width) << "  " << check.message << '\n'
            check.hint.try { |hint| io << "      " << " " * width << "  hint: " << hint << '\n' }
          end
          io << '\n' << summary << '\n'
        end
      end
    end
  end
end
